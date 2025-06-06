;; Legal Entity Verification Contract
;; Manages verification of legal entities before they can create contracts

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ENTITY_EXISTS (err u101))
(define-constant ERR_ENTITY_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Entity verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)

;; Data structure for legal entities
(define-map legal-entities
  { entity-id: uint }
  {
    name: (string-ascii 100),
    registration-number: (string-ascii 50),
    jurisdiction: (string-ascii 50),
    entity-type: (string-ascii 30),
    status: uint,
    verified-at: uint,
    verifier: principal
  }
)

;; Counter for entity IDs
(define-data-var next-entity-id uint u1)

;; Authorized verifiers
(define-map authorized-verifiers principal bool)

;; Initialize contract owner as authorized verifier
(map-set authorized-verifiers CONTRACT_OWNER true)

;; Register a new legal entity
(define-public (register-entity
  (name (string-ascii 100))
  (registration-number (string-ascii 50))
  (jurisdiction (string-ascii 50))
  (entity-type (string-ascii 30)))
  (let ((entity-id (var-get next-entity-id)))
    (asserts! (is-none (map-get? legal-entities { entity-id: entity-id })) ERR_ENTITY_EXISTS)
    (map-set legal-entities
      { entity-id: entity-id }
      {
        name: name,
        registration-number: registration-number,
        jurisdiction: jurisdiction,
        entity-type: entity-type,
        status: STATUS_PENDING,
        verified-at: u0,
        verifier: CONTRACT_OWNER
      }
    )
    (var-set next-entity-id (+ entity-id u1))
    (ok entity-id)
  )
)

;; Verify an entity (only authorized verifiers)
(define-public (verify-entity (entity-id uint) (approve bool))
  (let ((entity (unwrap! (map-get? legal-entities { entity-id: entity-id }) ERR_ENTITY_NOT_FOUND)))
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (map-set legal-entities
      { entity-id: entity-id }
      (merge entity {
        status: (if approve STATUS_VERIFIED STATUS_REJECTED),
        verified-at: block-height,
        verifier: tx-sender
      })
    )
    (ok true)
  )
)

;; Add authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-verifiers verifier true)
    (ok true)
  )
)

;; Get entity details
(define-read-only (get-entity (entity-id uint))
  (map-get? legal-entities { entity-id: entity-id })
)

;; Check if entity is verified
(define-read-only (is-entity-verified (entity-id uint))
  (match (map-get? legal-entities { entity-id: entity-id })
    entity (is-eq (get status entity) STATUS_VERIFIED)
    false
  )
)

;; Get next entity ID
(define-read-only (get-next-entity-id)
  (var-get next-entity-id)
)
