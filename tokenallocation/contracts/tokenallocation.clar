;; TokenAllocation Distribution Contract
;; Handles token distribution with enhanced security and control mechanisms

;; Define SIP-010 Fungible Token trait
(define-trait token-interface
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-label () (response (string-ascii 32) uint))
        (get-ticker () (response (string-ascii 32) uint))
        (get-precision () (response uint uint))
        (get-account-balance (principal) (response uint uint))
        (get-supply () (response uint uint))
        (get-resource-path () (response (optional (string-utf8 256)) uint))
    )
)

;; Error Codes
(define-constant UNAUTHORIZED (err u100))
(define-constant ALREADY-PROCESSED (err u101))
(define-constant NOT-QUALIFIED (err u102))
(define-constant AMOUNT-MISMATCH (err u103))
(define-constant INSUFFICIENT-FUNDS (err u104))
(define-constant DISTRIBUTION-PAUSED (err u105))
(define-constant TOKEN-UNDEFINED (err u106))
(define-constant INVALID-TOKEN (err u107))
(define-constant INVALID-QUANTITY (err u108))
(define-constant INVALID-TIMEFRAME (err u109))
(define-constant INVALID-PARTICIPANT (err u110))

;; Distribution Limits
(define-constant MAX-DISTRIBUTION-AMOUNT u1000000000)
(define-constant MIN-ALLOCATION u1)
(define-constant MAX-ALLOCATION-PERIOD u10000)
(define-constant SYSTEM-ADDRESS (as-contract tx-sender))

;; State Variables
(define-data-var protocol-admin principal tx-sender)
(define-data-var total-distribution-fund uint u0)
(define-data-var distribution-active bool true)
(define-data-var allocation-window-end uint u0)
(define-data-var allocation-per-participant uint u0)
(define-data-var registered-token (optional principal) none)

;; Tracking Maps
(define-map participant-allocations principal uint)
(define-map claimed-allocations principal uint)
(define-map approved-participants principal bool)
(define-map authorized-token-contracts principal bool)

;; Private Validation Functions
(define-private (validate-distribution-amount (quantity uint))
    (and 
        (>= quantity MIN-ALLOCATION)
        (<= quantity MAX-DISTRIBUTION-AMOUNT)
    )
)

(define-private (validate-allocation-period (duration uint))
    (<= duration MAX-ALLOCATION-PERIOD)
)

(define-private (validate-participant-address (participant principal))
    (and
        (not (is-eq participant SYSTEM-ADDRESS))
        (not (is-eq participant (var-get protocol-admin)))
    )
)

(define-private (is-token-approved (token principal))
    (default-to false (map-get? authorized-token-contracts token))
)

(define-private (verify-token-validity (token <token-interface>))
    (let ((token-principal (contract-of token)))
        (and 
            (is-token-approved token-principal)
            (match (contract-call? token get-label)
                success true
                error false)
        )
    )
)

;; Public Read Functions
(define-read-only (get-participant-status (participant principal))
    (default-to u0 (map-get? claimed-allocations participant))
)

(define-read-only (get-registered-token)
    (var-get registered-token)
)

(define-read-only (is-participant-qualified (participant principal))
    (is-some (map-get? participant-allocations participant))
)

(define-read-only (get-protocol-admin)
    (var-get protocol-admin)
)

(define-read-only (is-participant-approved (participant principal))
    (default-to false (map-get? approved-participants participant))
)

(define-read-only (get-distribution-details)
    (ok {
        total-fund: (var-get total-distribution-fund),
        status: (var-get distribution-active),
        allocation-deadline: (var-get allocation-window-end),
        participant-allocation: (var-get allocation-per-participant)
    })
)

;; Internal Eligibility Checker
(define-private (check-participant-qualification (participant principal))
    (and 
        (is-participant-qualified participant)
        (< (get-participant-status participant) (default-to u0 (map-get? participant-allocations participant)))
        (var-get distribution-active)
        (<= block-height (var-get allocation-window-end))
    )
)

;; Public Management Functions
(define-public (register-token-contract (token <token-interface>))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (match (contract-call? token get-label)
                    success true
                    error false) INVALID-TOKEN)
        (let ((token-principal (contract-of token)))
            (map-set authorized-token-contracts token-principal true)
            (var-set registered-token (some token-principal))
            (ok true)
        )
    )
)

(define-public (initialize-distribution (total-fund uint) (per-participant uint) (allocation-period uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (validate-distribution-amount total-fund) INVALID-QUANTITY)
        (asserts! (validate-distribution-amount per-participant) INVALID-QUANTITY)
        (asserts! (validate-allocation-period allocation-period) INVALID-TIMEFRAME)
        (asserts! (>= total-fund per-participant) INVALID-QUANTITY)
        
        (var-set total-distribution-fund total-fund)
        (var-set allocation-per-participant per-participant)
        (var-set allocation-window-end (+ block-height allocation-period))
        (var-set distribution-active true)
        (ok true)
    )
)

(define-public (approve-participant (participant principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (validate-participant-address participant) INVALID-PARTICIPANT)
        (asserts! (not (is-participant-approved participant)) ALREADY-PROCESSED)
        (map-set approved-participants participant true)
        (ok true)
    )
)

(define-public (revoke-participant-approval (participant principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (validate-participant-address participant) INVALID-PARTICIPANT)
        (asserts! (is-participant-approved participant) NOT-QUALIFIED)
        (map-delete approved-participants participant)
        (ok true)
    )
)

(define-public (set-participant-allocation (participant principal) (allocation uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (validate-participant-address participant) INVALID-PARTICIPANT)
        (asserts! (validate-distribution-amount allocation) INVALID-QUANTITY)
        (map-set participant-allocations participant allocation)
        (ok true)
    )
)

(define-public (claim-allocation (token <token-interface>))
    (let (
        (recipient tx-sender)
        (qualified-allocation (default-to u0 (map-get? participant-allocations recipient)))
        (claimed-amount (get-participant-status recipient))
        (registered-token-address (unwrap! (var-get registered-token) TOKEN-UNDEFINED))
    )
        (asserts! (validate-participant-address recipient) INVALID-PARTICIPANT)
        (asserts! (verify-token-validity token) INVALID-TOKEN)
        (asserts! (is-eq registered-token-address (contract-of token)) INVALID-TOKEN)
        (asserts! (check-participant-qualification recipient) NOT-QUALIFIED)
        (asserts! (>= (- qualified-allocation claimed-amount) (var-get allocation-per-participant)) INSUFFICIENT-FUNDS)
        
        ;; Update claimed allocation tracking
        (map-set claimed-allocations recipient (+ claimed-amount (var-get allocation-per-participant)))
        
        ;; Transfer tokens using token interface
        (as-contract
            (contract-call? token transfer
                (var-get allocation-per-participant)
                tx-sender
                recipient
                none
            )
        )
    )
)

(define-public (terminate-distribution)
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (var-set distribution-active false)
        (ok true)
    )
)

;; Emergency Adjustment Functions
(define-public (adjust-allocation-window (new-deadline uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (validate-allocation-period (- new-deadline block-height)) INVALID-TIMEFRAME)
        (var-set allocation-window-end new-deadline)
        (ok true)
    )
)

(define-public (emergency-token-withdrawal (token <token-interface>) (amount uint))
    (let ((registered-token-address (unwrap! (var-get registered-token) TOKEN-UNDEFINED)))
        (asserts! (is-eq tx-sender (var-get protocol-admin)) UNAUTHORIZED)
        (asserts! (validate-distribution-amount amount) INVALID-QUANTITY)
        (asserts! (verify-token-validity token) INVALID-TOKEN)
        (asserts! (is-eq (contract-of token) registered-token-address) INVALID-TOKEN)
        (as-contract
            (contract-call? token transfer
                amount
                tx-sender
                (var-get protocol-admin)
                none
            )
        )
    )
)