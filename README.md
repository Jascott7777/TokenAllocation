# TokenAllocation: Decentralized Token Distribution Protocol

## Overview

TokenAllocation is a secure, flexible smart contract for managing token distributions on the Stacks blockchain. It provides a robust mechanism for controlled token allocation with granular administrative controls.

## Features

- **Controlled Distribution**: Precisely manage token allocations for participants
- **Whitelist Mechanism**: Approve and manage eligible recipients
- **Configurable Parameters**: 
  - Set total distribution fund
  - Define per-participant allocation
  - Configure time-limited distribution windows

- **Security Measures**:
  - Multiple validation checks
  - Admin-only critical function access
  - Prevents double-claiming
  - Emergency withdrawal options

## Prerequisites

- Clarinet
- SIP-010 Fungible Token Contract
- Stacks Blockchain Environment

## Installation

1. Clone the repository
2. Install dependencies
3. Deploy using Clarinet

```bash
clarinet contracts deploy
```

## Contract Functions

### Admin Functions
- `register-token-contract`: Set approved token contract
- `initialize-distribution`: Configure distribution parameters
- `approve-participant`: Whitelist distribution recipients
- `set-participant-allocation`: Define individual allocation amounts
- `terminate-distribution`: Pause entire distribution process

### Participant Functions
- `claim-allocation`: Claim token allocation
- `get-distribution-details`: Retrieve current distribution status

### Emergency Functions
- `adjust-allocation-window`: Modify distribution timeline
- `emergency-token-withdrawal`: Retrieve tokens in exceptional circumstances

## Error Handling

Comprehensive error codes prevent unauthorized actions and protect against common distribution vulnerabilities:
- Unauthorized access attempts
- Double-claiming prevention
- Invalid token interactions
- Allocation limit enforcement

## Security Considerations

- Only contract admin can modify critical parameters
- Strict validation on all input parameters
- Time-limited distribution window
- Emergency withdrawal mechanism

## Deployment Recommendations

1. Thoroughly test distribution scenarios
2. Verify token contract compatibility
3. Set reasonable allocation limits
4. Implement careful participant management

## Contributing

Contributions welcome. Please:
- Follow existing code structure
- Add comprehensive tests
- Document new features


## Contact

Reach out for support, questions, or collaboration.