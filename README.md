KYCSecure
=========

Decentralized Identity Verification and KYC Contract
----------------------------------------------------

KYCSecure is a Clarity smart contract designed to provide a robust and decentralized system for identity verification and Know Your Customer (KYC) compliance on the Stacks blockchain. It empowers users to register their identities, submit necessary verification documents, and allows authorized third-party verifiers to approve various levels of KYC compliance (Basic, Intermediate, Advanced). The contract prioritizes privacy and security while offering a transparent and auditable verification process.

### ✨ Features

-   **Identity Registration:** Users can register their unique identities on the blockchain.

-   **Multi-Level KYC:** Supports different levels of KYC verification (Basic, Intermediate, Advanced) based on the depth of compliance required.

-   **Authorized Verifiers:** A system for the contract owner to authorize specific entities to perform KYC verification, along with their maximum allowed verification level.

-   **Pending Verification Requests:** Manages and tracks user-submitted KYC requests awaiting approval from authorized verifiers.

-   **Privacy-Preserving Document Handling:** Stores only a cryptographic hash of the verification documents, ensuring user document privacy while allowing for integrity checks.

-   **Expiration Mechanism:** KYC verifications have an expiration date, requiring periodic re-verification.

-   **KYC Analytics & Batch Operations:** Provides advanced functionality for compliance monitoring, allowing authorized entities to perform batch operations and retrieve detailed analytics on user KYC statuses.

-   **Contract Pause Mechanism:** An emergency control to temporarily pause contract operations.

### 📜 Contract Details

This section outlines the core components of the `KYCSecure` contract.

#### Constants

| Constant                | Value       | Description                                                                 |
| :---------------------- | :---------- | :-------------------------------------------------------------------------- |
| `CONTRACT-OWNER`        | `tx-sender` | The principal (address) that deployed the contract, designated as the owner. |
| `ERR-UNAUTHORIZED`      | `u100`      | Returned when the caller does not have the necessary permissions.           |
| `ERR-ALREADY-REGISTERED`| `u101`      | Returned when a user attempts to register an already registered identity.   |
| `ERR-NOT-FOUND`         | `u102`      | Returned when a requested identity or verification request is not found.    |
| `ERR-INVALID-LEVEL`     | `u103`      | Returned when an invalid KYC level is provided.                             |
| `ERR-ALREADY-VERIFIED`  | `u104`      | * (Not explicitly used but reserved) * |
| `ERR-INSUFFICIENT-LEVEL`| `u105`      | * (Not explicitly used but reserved) * |
| `ERR-EXPIRED`           | `u106`      | * (Not explicitly used but reserved) * |
| `LEVEL-BASIC`           | `u1`        | Represents the basic KYC verification level.                                |
| `LEVEL-INTERMEDIATE`    | `u2`        | Represents the intermediate KYC verification level.                         |
| `LEVEL-ADVANCED`        | `u3`        | Represents the advanced KYC verification level.                             |

#### Data Maps and Variables

-   **`identities`**

    -   **Description:** Stores registered identities and their current KYC status.

    -   **Key:**  `{ user: principal }` - The principal (address) of the identity holder.

    -   **Value:**  `{ registered-at: uint, kyc-level: uint, verified-at: uint, verifier: (optional principal), expires-at: uint, document-hash: (buff 32), is-active: bool }`

        -   `registered-at`: Block height when the identity was registered.

        -   `kyc-level`: Current KYC level (u0 if not verified).

        -   `verified-at`: Block height when the identity was last verified.

        -   `verifier`: Optional principal of the verifier who last approved the KYC.

        -   `expires-at`: Block height when the current KYC verification expires.

        -   `document-hash`: Hash of the verification document (e.g., SHA256 of the document).

        -   `is-active`: Boolean indicating if the identity is active.

-   **`authorized-verifiers`**

    -   **Description:** Stores principals authorized to perform KYC verification and their maximum allowed verification level.

    -   **Key:**  `{ verifier: principal }` - The principal of the authorized verifier.

    -   **Value:**  `{ max-level: uint, authorized-at: uint, authorized-by: principal, is-active: bool }`

        -   `max-level`: The highest KYC level this verifier can approve.

        -   `authorized-at`: Block height when the verifier was authorized.

        -   `authorized-by`: Principal who authorized this verifier (usually `CONTRACT-OWNER`).

        -   `is-active`: Boolean indicating if the verifier is currently active.

-   **`pending-verifications`**

    -   **Description:** Stores KYC verification requests awaiting approval.

    -   **Key:**  `{ user: principal, request-id: uint }` - The user and a unique request identifier.

    -   **Value:**  `{ requested-level: uint, document-hash: (buff 32), submitted-at: uint, metadata: (string-ascii 256) }`

        -   `requested-level`: The KYC level requested by the user.

        -   `document-hash`: Hash of the document submitted for this request.

        -   `submitted-at`: Block height when the request was submitted.

        -   `metadata`: Optional additional information about the request.

-   **`next-request-id`** (Data Variable)

    -   **Description:** A counter to generate unique `request-id`s for `pending-verifications`.

    -   **Type:**  `uint`

    -   **Initial Value:**  `u1`

-   **`contract-paused`** (Data Variable)

    -   **Description:** A boolean flag to pause/unpause the entire contract in emergency situations.

    -   **Type:**  `bool`

    -   **Initial Value:**  `false`

### ⚙️ Functions

#### Public Functions

These functions can be called by anyone, but some have access control restrictions.

1.  **`register-identity`**

    -   `register-identity (document-hash (buff 32))`

    -   **Description:** Allows any user to register their identity in the system. The user must provide a cryptographic hash of their identity document.

    -   **Parameters:**

        -   `document-hash`: A `(buff 32)` representing the hash of the user's identity document.

    -   **Returns:**  `(ok true)` on success, or an error.

    -   **Errors:**  `ERR-UNAUTHORIZED` (if contract paused), `ERR-ALREADY-REGISTERED`.

2.  **`submit-kyc-request`**

    -   `submit-kyc-request (requested-level uint) (document-hash (buff 32)) (metadata (string-ascii 256))`

    -   **Description:** Allows a registered user to submit a request for KYC verification at a specified level.

    -   **Parameters:**

        -   `requested-level`: The desired KYC level (`LEVEL-BASIC`, `LEVEL-INTERMEDIATE`, `LEVEL-ADVANCED`).

        -   `document-hash`: A `(buff 32)` representing the hash of the document submitted for this specific KYC request.

        -   `metadata`: A `(string-ascii 256)` for optional additional information.

    -   **Returns:**  `(ok request-id)` on success, where `request-id` is the ID of the new request.

    -   **Errors:**  `ERR-UNAUTHORIZED` (if contract paused), `ERR-INVALID-LEVEL`, `ERR-NOT-FOUND` (if user not registered).

3.  **`approve-kyc-verification`**

    -   `approve-kyc-verification (user principal) (request-id uint)`

    -   **Description:** Allows an authorized verifier to approve a pending KYC verification request for a specific user.

    -   **Parameters:**

        -   `user`: The principal (address) of the user whose request is being approved.

        -   `request-id`: The ID of the pending request.

    -   **Returns:**  `(ok true)` on success, or an error.

    -   **Errors:**  `ERR-UNAUTHORIZED` (if contract paused or verifier not authorized for the level), `ERR-NOT-FOUND` (if request or user identity not found).

4.  **`authorize-verifier`**

    -   `authorize-verifier (verifier principal) (max-level uint)`

    -   **Description:** Allows the `CONTRACT-OWNER` to add or update an authorized KYC verifier and set their maximum verification level.

    -   **Parameters:**

        -   `verifier`: The principal (address) of the entity to authorize.

        -   `max-level`: The maximum KYC level this verifier is allowed to approve.

    -   **Returns:**  `(ok true)` on success, or an error.

    -   **Errors:**  `ERR-UNAUTHORIZED` (if caller is not `CONTRACT-OWNER`), `ERR-INVALID-LEVEL`.

5.  **`batch-kyc-analytics-and-operations`**

    -   `batch-kyc-analytics-and-operations (users (list 10 principal)) (operation-type (string-ascii 20)) (min-level uint) (include-expired bool)`

    -   **Description:** Provides comprehensive analytics for KYC compliance monitoring and enables batch operations for efficient identity management. Only the `CONTRACT-OWNER` or an authorized verifier can call this.

    -   **Parameters:**

        -   `users`: A list of up to 10 principals to process.

        -   `operation-type`: A string indicating the type of operation ("RENEWAL_ALERT", "COMPLIANCE_CHECK", or any other string for basic summary).

        -   `min-level`: The minimum KYC level required for compliance checks.

        -   `include-expired`: A boolean to include expired users in the analysis for "COMPLIANCE_CHECK" (though the internal logic primarily uses it for identifying expired users).

    -   **Returns:**  `(ok { ... })` A tuple containing analytics results, including `total-processed`, `valid-count`, `expired-count`, `compliance-rate`, `operation-type`, `processed-at`, `min-level-required`, and `detailed-results` (if `COMPLIANCE_CHECK`).

    -   **Errors:**  `ERR-UNAUTHORIZED` (if caller is not owner or authorized verifier), `ERR-INVALID-LEVEL`.

#### Read-Only Functions

These functions can be called by anyone to retrieve information from the contract without modifying its state.

1.  **`get-identity`**

    -   `get-identity (user principal)`

    -   **Description:** Retrieves the identity information for a given user.

    -   **Parameters:**

        -   `user`: The principal (address) of the user.

    -   **Returns:**  `(some { ... })` with identity details if found, `none` otherwise.

2.  **`has-valid-kyc`**

    -   `has-valid-kyc (user principal) (min-level uint)`

    -   **Description:** Checks if a user has a minimum required KYC level and if their verification is not expired.

    -   **Parameters:**

        -   `user`: The principal (address) of the user.

        -   `min-level`: The minimum KYC level to check against.

    -   **Returns:**  `true` if the user has valid KYC at or above the `min-level` and it's not expired, `false` otherwise.

3.  **`get-pending-request`**

    -   `get-pending-request (user principal) (request-id uint)`

    -   **Description:** Retrieves the details of a specific pending verification request.

    -   **Parameters:**

        -   `user`: The principal (address) of the user who submitted the request.

        -   `request-id`: The ID of the pending request.

    -   **Returns:**  `(some { ... })` with request details if found, `none` otherwise.

4.  **`is-authorized-verifier`**

    -   `is-authorized-verifier (verifier principal)`

    -   **Description:** Checks if a given principal is an authorized and active verifier.

    -   **Parameters:**

        -   `verifier`: The principal (address) to check.

    -   **Returns:**  `true` if the principal is an active authorized verifier, `false` otherwise.

#### Private Functions

These functions are internal helpers used within the contract and cannot be called directly from outside.

-   `is-contract-active`: Checks if the contract is currently active (not paused).

-   `is-valid-kyc-level`: Validates if a provided KYC level is within the acceptable range (`u1` to `u3`).

-   `can-verify-level`: Determines if a given verifier is authorized to approve a specific KYC level.

-   `calculate-expiration`: Calculates the expiration block height for a KYC verification based on its level.

-   `process-user-analytics`: Helper for `batch-kyc-analytics-and-operations` to retrieve and format an individual user's KYC data.

-   `is-user-valid-for-operation`: Helper to filter users who are active, not expired, and have a KYC level greater than 0.

-   `is-user-expired`: Helper to identify users whose KYC is expired or expiring soon.

-   `send-renewal-notification`: A placeholder function that would typically trigger an external notification system for users needing KYC renewal.

### 🚀 Deployment

To deploy this contract, you will need the Stacks CLI or a compatible wallet.

1.  **Save the contract:** Save the Clarity code into a file, e.g., `kyc-secure.clar`.

2.  **Deploy using Stacks CLI:**

    ```
    clarity-cli tx deploy kyc-secure.clar <YOUR_STX_ADDRESS>

    ```

    Replace `<YOUR_STX_ADDRESS>` with the address you want to deploy from. This address will become the `CONTRACT-OWNER`.

### 💡 Usage Examples

Here are some conceptual examples of how to interact with the `KYCSecure` contract using typical Clarity interaction patterns. Replace `<contract-address>` with the actual address where the contract is deployed.

Assume the contract is deployed at `SP123...XYZ.kyc-secure`.

```
;; 1. Authorize a Verifier (by CONTRACT-OWNER)
;; Let 'ST1A...BCD' be the address of the verifier.
(as-contract tx-sender (contract-call? 'SP123...XYZ.kyc-secure' authorize-verifier 'ST1A...BCD' u3))
;; Expected: (ok true)

;; 2. Register an Identity (by a User)
;; Let 'ST2E...FGH' be the address of the user.
;; document-hash example (replace with actual document hash)
(as-contract tx-sender (contract-call? 'SP123...XYZ.kyc-secure' register-identity 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef))
;; Expected: (ok true)

;; 3. Submit a KYC Request (by the User 'ST2E...FGH')
(as-contract tx-sender (contract-call? 'SP123...XYZ.kyc-secure' submit-kyc-request u2 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890123456 'Intermediate KYC Request'))
;; Expected: (ok u1) (assuming this is the first request, request-id u1)

;; 4. Get Pending Request Details (Read-only)
(contract-call? 'SP123...XYZ.kyc-secure' get-pending-request 'ST2E...FGH' u1)
;; Expected: (some { ... request details ... })

;; 5. Approve KYC Verification (by the Verifier 'ST1A...BCD')
(as-contract tx-sender (contract-call? 'SP123...XYZ.kyc-secure' approve-kyc-verification 'ST2E...FGH' u1))
;; Expected: (ok true)

;; 6. Get Identity Information (Read-only)
(contract-call? 'SP123...XYZ.kyc-secure' get-identity 'ST2E...FGH')
;; Expected: (some { ... identity details including kyc-level: u2 ... })

;; 7. Check if User has Valid KYC (Read-only)
(contract-call? 'SP123...XYZ.kyc-secure' has-valid-kyc 'ST2E...FGH' u1)
;; Expected: true

(contract-call? 'SP123...XYZ.kyc-secure' has-valid-kyc 'ST2E...FGH' u3)
;; Expected: false (since they are only Intermediate)

;; 8. Perform Batch KYC Analytics (by CONTRACT-OWNER or Authorized Verifier)
;; Assuming 'ST2E...FGH' and 'ST3I...JKL' are registered users
(as-contract tx-sender (contract-call? 'SP123...XYZ.kyc-secure' batch-kyc-analytics-and-operations (list 'ST2E...FGH' 'ST3I...JKL') "COMPLIANCE_CHECK" u1 true))
;; Expected: (ok { detailed-results: (list { ... ST2E...FGH analytics ... }, { ... ST3I...JKL analytics ... }), ... summary ... })

```

### 🤝 Contributing

Contributions are welcome! If you find a bug, have a feature request, or want to contribute code, please follow these steps:

1.  Fork the repository.

2.  Create a new branch (`git checkout -b feature/your-feature-name` or `bugfix/issue-description`).

3.  Make your changes.

4.  Write clear and concise commit messages.

5.  Push your branch to your fork.

6.  Open a pull request to the main repository.

### 🔒 Security Considerations

While this contract provides a framework for decentralized identity and KYC, it's crucial to understand the following:

-   **Document Storage:** The contract only stores a hash of the documents. The actual documents are managed off-chain, and their storage and security are outside the scope of this smart contract.

-   **Verifier Trust:** The integrity of the KYC process heavily relies on the trustworthiness and diligence of the authorized verifiers. The contract provides the mechanism, but the due diligence of verifiers is paramount.

-   **Hash Collisions:** While unlikely, cryptographic hash collisions are theoretically possible. Using strong hashing algorithms (e.g., SHA256 as implied by `buff 32`) minimizes this risk.

-   **Block Height Dependence:** Expiration is tied to `block-height`. Fluctuations in block production times could slightly affect exact timeframes.

-   **`CONTRACT-OWNER` Security:** The `CONTRACT-OWNER` has significant power (e.g., authorizing verifiers, pausing the contract). Securing the `CONTRACT-OWNER`'s private key is critical.

Always perform thorough audits and testing before deploying smart contracts to a production environment.

### 📄 License

This project is licensed under the MIT License - see the <LICENSE> file for details.

### ❓ Support

For questions, issues, or support, please open an issue on the GitHub repository.
