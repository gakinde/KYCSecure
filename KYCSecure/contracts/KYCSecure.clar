;; Decentralized Identity Verification and KYC Contract
;; This contract provides a decentralized system for identity verification and Know Your Customer (KYC) compliance.
;; It allows users to register identities, submit verification documents, and enables authorized verifiers
;; to approve different levels of KYC compliance while maintaining privacy and security.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-LEVEL (err u103))
(define-constant ERR-ALREADY-VERIFIED (err u104))
(define-constant ERR-INSUFFICIENT-LEVEL (err u105))
(define-constant ERR-EXPIRED (err u106))

;; KYC verification levels
(define-constant LEVEL-BASIC u1)
(define-constant LEVEL-INTERMEDIATE u2)
(define-constant LEVEL-ADVANCED u3)

;; Data Maps and Variables

;; Track registered identities with their basic information
(define-map identities
  { user: principal }
  {
    registered-at: uint,
    kyc-level: uint,
    verified-at: uint,
    verifier: (optional principal),
    expires-at: uint,
    document-hash: (buff 32),
    is-active: bool
  }
)

;; Store authorized KYC verifiers and their maximum verification level
(define-map authorized-verifiers
  { verifier: principal }
  {
    max-level: uint,
    authorized-at: uint,
    authorized-by: principal,
    is-active: bool
  }
)

;; Track verification requests pending approval
(define-map pending-verifications
  { user: principal, request-id: uint }
  {
    requested-level: uint,
    document-hash: (buff 32),
    submitted-at: uint,
    metadata: (string-ascii 256)
  }
)

;; Counter for verification request IDs
(define-data-var next-request-id uint u1)

;; Contract pause mechanism for emergency situations
(define-data-var contract-paused bool false)

;; Private Functions

;; Check if the contract is not paused
(define-private (is-contract-active)
  (not (var-get contract-paused))
)

;; Validate KYC level is within acceptable range
(define-private (is-valid-kyc-level (level uint))
  (and (>= level LEVEL-BASIC) (<= level LEVEL-ADVANCED))
)

;; Check if a verifier is authorized for a specific level
(define-private (can-verify-level (verifier principal) (level uint))
  (match (map-get? authorized-verifiers { verifier: verifier })
    verifier-data (and 
      (get is-active verifier-data)
      (>= (get max-level verifier-data) level)
    )
    false
  )
)

;; Calculate expiration time based on KYC level (higher levels last longer)
(define-private (calculate-expiration (level uint))
  (+ block-height 
    (if (is-eq level LEVEL-ADVANCED)
      u52560  ;; ~1 year for advanced
      (if (is-eq level LEVEL-INTERMEDIATE)
        u26280  ;; ~6 months for intermediate
        u8760   ;; ~2 months for basic
      )
    )
  )
)

;; Public Functions

;; Register a new identity in the system
(define-public (register-identity (document-hash (buff 32)))
  (let ((user tx-sender))
    (asserts! (is-contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-none (map-get? identities { user: user })) ERR-ALREADY-REGISTERED)
    
    (map-set identities
      { user: user }
      {
        registered-at: block-height,
        kyc-level: u0,
        verified-at: u0,
        verifier: none,
        expires-at: u0,
        document-hash: document-hash,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Submit a KYC verification request
(define-public (submit-kyc-request (requested-level uint) (document-hash (buff 32)) (metadata (string-ascii 256)))
  (let (
    (user tx-sender)
    (request-id (var-get next-request-id))
  )
    (asserts! (is-contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-valid-kyc-level requested-level) ERR-INVALID-LEVEL)
    (asserts! (is-some (map-get? identities { user: user })) ERR-NOT-FOUND)
    
    (map-set pending-verifications
      { user: user, request-id: request-id }
      {
        requested-level: requested-level,
        document-hash: document-hash,
        submitted-at: block-height,
        metadata: metadata
      }
    )
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Approve a KYC verification request (verifiers only)
(define-public (approve-kyc-verification (user principal) (request-id uint))
  (let (
    (verifier tx-sender)
    (request-key { user: user, request-id: request-id })
  )
    (asserts! (is-contract-active) ERR-UNAUTHORIZED)
    
    (match (map-get? pending-verifications request-key)
      request-data (begin
        (asserts! (can-verify-level verifier (get requested-level request-data)) ERR-UNAUTHORIZED)
        
        (map-set identities
          { user: user }
          (merge 
            (unwrap! (map-get? identities { user: user }) ERR-NOT-FOUND)
            {
              kyc-level: (get requested-level request-data),
              verified-at: block-height,
              verifier: (some verifier),
              expires-at: (calculate-expiration (get requested-level request-data)),
              document-hash: (get document-hash request-data)
            }
          )
        )
        (map-delete pending-verifications request-key)
        (ok true)
      )
      ERR-NOT-FOUND
    )
  )
)

;; Add or update an authorized verifier (contract owner only)
(define-public (authorize-verifier (verifier principal) (max-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-valid-kyc-level max-level) ERR-INVALID-LEVEL)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        max-level: max-level,
        authorized-at: block-height,
        authorized-by: CONTRACT-OWNER,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Get identity information for a user
(define-read-only (get-identity (user principal))
  (map-get? identities { user: user })
)

;; Check if a user has a minimum KYC level and it's not expired
(define-read-only (has-valid-kyc (user principal) (min-level uint))
  (match (map-get? identities { user: user })
    identity-data (and
      (get is-active identity-data)
      (>= (get kyc-level identity-data) min-level)
      (> (get expires-at identity-data) block-height)
    )
    false
  )
)

;; Get pending verification request details
(define-read-only (get-pending-request (user principal) (request-id uint))
  (map-get? pending-verifications { user: user, request-id: request-id })
)

;; Check if a principal is an authorized verifier
(define-read-only (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers { verifier: verifier })
    verifier-data (get is-active verifier-data)
    false
  )
)

;; Advanced KYC Analytics and Batch Operations Function
;; This function provides comprehensive analytics for KYC compliance monitoring
;; and enables batch operations for efficient identity management
(define-public (batch-kyc-analytics-and-operations 
  (users (list 10 principal))
  (operation-type (string-ascii 20))
  (min-level uint)
  (include-expired bool))
  (let (
    (caller tx-sender)
    (current-block block-height)
  )
    ;; Ensure caller is authorized (either contract owner or authorized verifier)
    (asserts! (or 
      (is-eq caller CONTRACT-OWNER)
      (is-authorized-verifier caller)
    ) ERR-UNAUTHORIZED)
    
    (asserts! (is-contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-valid-kyc-level min-level) ERR-INVALID-LEVEL)
    
    ;; Process each user and collect analytics
    (let (
      (analytics-results (map process-user-analytics users))
      (valid-users (filter is-user-valid-for-operation analytics-results))
      (expired-users (filter is-user-expired analytics-results))
      (base-compliance-summary {
        total-processed: (len users),
        valid-count: (len valid-users),
        expired-count: (len expired-users),
        compliance-rate: (if (> (len users) u0)
          (/ (* (len valid-users) u100) (len users))
          u0
        ),
        operation-type: operation-type,
        processed-at: current-block,
        min-level-required: min-level,
        detailed-results: (list)  ;; Initialize as empty list with correct type
      })
    )
      
      ;; Execute batch operations based on operation type
      (if (is-eq operation-type "RENEWAL_ALERT")
        (begin
          ;; Send renewal alerts for users with expiring KYC
          (map send-renewal-notification expired-users)
          (ok base-compliance-summary)
        )
        (if (is-eq operation-type "COMPLIANCE_CHECK")
          ;; Return detailed compliance analysis
          (ok (merge base-compliance-summary {
            detailed-results: analytics-results
          }))
          ;; Default: return basic summary (keep detailed-results as empty list)
          (ok base-compliance-summary)
        )
      )
    )
  )
)

;; Helper function to process individual user analytics
(define-private (process-user-analytics (user principal))
  (match (map-get? identities { user: user })
    identity-data {
      user: user,
      kyc-level: (get kyc-level identity-data),
      is-expired: (<= (get expires-at identity-data) block-height),
      days-until-expiry: (if (> (get expires-at identity-data) block-height)
        (- (get expires-at identity-data) block-height)
        u0
      ),
      is-active: (get is-active identity-data),
      verified-at: (get verified-at identity-data),
      verifier: (get verifier identity-data)
    }
    {
      user: user,
      kyc-level: u0,
      is-expired: true,
      days-until-expiry: u0,
      is-active: false,
      verified-at: u0,
      verifier: none
    }
  )
)

;; Helper function to check if user is valid for operations
(define-private (is-user-valid-for-operation (user-data { user: principal, kyc-level: uint, is-expired: bool, days-until-expiry: uint, is-active: bool, verified-at: uint, verifier: (optional principal) }))
  (and 
    (get is-active user-data)
    (not (get is-expired user-data))
    (> (get kyc-level user-data) u0)
  )
)

;; Helper function to identify expired users
(define-private (is-user-expired (user-data { user: principal, kyc-level: uint, is-expired: bool, days-until-expiry: uint, is-active: bool, verified-at: uint, verifier: (optional principal) }))
  (or 
    (get is-expired user-data)
    (< (get days-until-expiry user-data) u1440) ;; Expiring within ~1 week
  )
)

;; Helper function to send renewal notifications (placeholder for external integration)
(define-private (send-renewal-notification (user-data { user: principal, kyc-level: uint, is-expired: bool, days-until-expiry: uint, is-active: bool, verified-at: uint, verifier: (optional principal) }))
  ;; In a real implementation, this would trigger external notification systems
  ;; For now, it returns the user data for processing
  user-data
)


