;; Amendment Tracking Contract
;; Tracks amendments to existing contracts

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_CONTRACT_NOT_FOUND (err u301))
(define-constant ERR_AMENDMENT_NOT_FOUND (err u302))
(define-constant ERR_INVALID_STATUS (err u303))

;; Amendment status
(define-constant AMENDMENT_PROPOSED u0)
(define-constant AMENDMENT_APPROVED u1)
(define-constant AMENDMENT_REJECTED u2)
(define-constant AMENDMENT_EXECUTED u3)

;; Amendment data structure
(define-map amendments
  { amendment-id: uint }
  {
    contract-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    amendment-hash: (buff 32),
    status: uint,
    proposed-at: uint,
    proposed-by: principal,
    approved-by-a: bool,
    approved-by-b: bool,
    executed-at: uint
  }
)

;; Amendment counter
(define-data-var next-amendment-id uint u1)

;; Contract amendments mapping
(define-map contract-amendments
  { contract-id: uint }
  (list 50 uint)
)

;; Propose an amendment
(define-public (propose-amendment
  (contract-id uint)
  (title (string-ascii 100))
  (description (string-ascii 500))
  (amendment-hash (buff 32)))
  (let ((amendment-id (var-get next-amendment-id)))
    ;; TODO: Verify contract exists and caller is authorized

    (map-set amendments
      { amendment-id: amendment-id }
      {
        contract-id: contract-id,
        title: title,
        description: description,
        amendment-hash: amendment-hash,
        status: AMENDMENT_PROPOSED,
        proposed-at: block-height,
        proposed-by: tx-sender,
        approved-by-a: false,
        approved-by-b: false,
        executed-at: u0
      }
    )

    ;; Add to contract amendments list
    (let ((current-amendments (default-to (list) (map-get? contract-amendments { contract-id: contract-id }))))
      (map-set contract-amendments
        { contract-id: contract-id }
        (unwrap! (as-max-len? (append current-amendments amendment-id) u50) (err u999))
      )
    )

    (var-set next-amendment-id (+ amendment-id u1))
    (ok amendment-id)
  )
)

;; Approve amendment
(define-public (approve-amendment (amendment-id uint) (entity-id uint))
  (let ((amendment (unwrap! (map-get? amendments { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND)))
    ;; TODO: Verify caller is authorized representative for entity
    ;; TODO: Verify entity is party to the contract

    ;; Update approval status based on entity
    (map-set amendments
      { amendment-id: amendment-id }
      (merge amendment {
        approved-by-a: true,  ;; Simplified - would check which party
        approved-by-b: false
      })
    )
    (ok true)
  )
)

;; Execute amendment (when approved by both parties)
(define-public (execute-amendment (amendment-id uint))
  (let ((amendment (unwrap! (map-get? amendments { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND)))
    (asserts! (and (get approved-by-a amendment) (get approved-by-b amendment)) ERR_UNAUTHORIZED)
    (map-set amendments
      { amendment-id: amendment-id }
      (merge amendment {
        status: AMENDMENT_EXECUTED,
        executed-at: block-height
      })
    )
    (ok true)
  )
)

;; Get amendment details
(define-read-only (get-amendment (amendment-id uint))
  (map-get? amendments { amendment-id: amendment-id })
)

;; Get contract amendments
(define-read-only (get-contract-amendments (contract-id uint))
  (map-get? contract-amendments { contract-id: contract-id })
)

;; Get amendment history for contract
(define-read-only (get-amendment-history (contract-id uint))
  (map-get? contract-amendments { contract-id: contract-id })
)
