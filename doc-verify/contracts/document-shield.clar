;; Document Verification Smart Contract

;; Error codes
(define-constant ERROR-OWNER-ACCESS-DENIED (err u100))
(define-constant ERROR-DOCUMENT-ALREADY-EXISTS (err u101))
(define-constant ERROR-DOCUMENT-LOOKUP-FAILED (err u102))
(define-constant ERROR-VERIFICATION-ALREADY-COMPLETE (err u103))
(define-constant ERROR-INVALID-HASH-FORMAT (err u104))
(define-constant ERROR-INVALID-CONTENT-HASH (err u105))
(define-constant ERROR-INVALID-METADATA-FORMAT (err u106))
(define-constant ERROR-INVALID-VERIFIER-ADDRESS (err u107))
(define-constant ERROR-INVALID-INPUT-PARAMETER (err u108))
(define-constant ERROR-PERMISSION-DENIED (err u109))

;; Constants for verification status
(define-constant DOCUMENT-STATUS-PENDING "PENDING")
(define-constant DOCUMENT-STATUS-VERIFIED "VERIFIED")

;; Define document record structure
(define-data-var document-template 
    {
        document-owner: principal,
        document-content-hash: (buff 32),
        submission-timestamp: uint,
        verification-status: (string-ascii 20),
        document-verifier: (optional principal),
        document-metadata: (string-utf8 256),
        document-version: uint,
        verification-completed: bool
    }
    {
        document-owner: tx-sender,
        document-content-hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
        submission-timestamp: u0,
        verification-status: DOCUMENT-STATUS-PENDING,
        document-verifier: none,
        document-metadata: u"",
        document-version: u0,
        verification-completed: false
    }
)

;; Data maps
(define-map verified-documents
    { document-unique-hash: (buff 32) }
    {
        document-owner: principal,
        document-content-hash: (buff 32),
        submission-timestamp: uint,
        verification-status: (string-ascii 20),
        document-verifier: (optional principal),
        document-metadata: (string-utf8 256),
        document-version: uint,
        verification-completed: bool
    }
)

(define-map document-permissions
    { document-unique-hash: (buff 32), verifier-address: principal }
    { has-view-access: bool, has-verification-rights: bool }
)

;; Validation functions with strict checks
(define-private (validate-document-unique-hash (unique-hash-input (buff 32)))
    (if (is-eq (len unique-hash-input) u32)
        (ok unique-hash-input)
        ERROR-INVALID-INPUT-PARAMETER))

(define-private (validate-document-metadata-content (metadata-input (string-utf8 256)))
    (if (and (<= (len metadata-input) u256) (> (len metadata-input) u0))
        (ok metadata-input)
        ERROR-INVALID-INPUT-PARAMETER))

(define-private (validate-verifier-address (verifier-address-input principal))
    (if (and 
        (not (is-eq verifier-address-input tx-sender))
        (not (is-eq verifier-address-input (as-contract tx-sender))))
        (ok verifier-address-input)
        ERROR-INVALID-VERIFIER-ADDRESS))

;; Safe getter with error handling
(define-private (retrieve-document-record (document-unique-hash (buff 32)))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash (match (map-get? verified-documents { document-unique-hash: validated-unique-hash })
            document-record (ok document-record)
            ERROR-DOCUMENT-LOOKUP-FAILED)
        error ERROR-INVALID-HASH-FORMAT))

;; Read-only functions with validation
(define-read-only (get-document-details (document-unique-hash (buff 32)))
    (retrieve-document-record document-unique-hash))

(define-read-only (get-verifier-permissions-status (document-unique-hash (buff 32)) (verifier-address principal))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash (match (validate-verifier-address verifier-address)
            validated-verifier-address (match (map-get? document-permissions 
                { document-unique-hash: validated-unique-hash, verifier-address: validated-verifier-address })
                permission-status (ok permission-status)
                (ok { has-view-access: false, has-verification-rights: false }))
            error ERROR-INVALID-VERIFIER-ADDRESS)
        error ERROR-INVALID-HASH-FORMAT))

;; Public functions with security
(define-public (submit-new-document 
    (document-unique-hash (buff 32))
    (document-content-hash (buff 32))
    (document-metadata-content (string-utf8 256)))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash (match (validate-document-unique-hash document-content-hash)
            validated-content-hash (match (validate-document-metadata-content document-metadata-content)
                validated-metadata-content 
                (match (map-get? verified-documents { document-unique-hash: validated-unique-hash })
                    existing-document-record ERROR-DOCUMENT-ALREADY-EXISTS
                    (ok (map-set verified-documents
                        { document-unique-hash: validated-unique-hash }
                        {
                            document-owner: tx-sender,
                            document-content-hash: validated-content-hash,
                            submission-timestamp: block-height,
                            verification-status: DOCUMENT-STATUS-PENDING,
                            document-verifier: none,
                            document-metadata: validated-metadata-content,
                            document-version: u1,
                            verification-completed: false
                        })))
                error ERROR-INVALID-METADATA-FORMAT)
            error ERROR-INVALID-CONTENT-HASH)
        error ERROR-INVALID-HASH-FORMAT))

(define-public (update-document-content
    (document-unique-hash (buff 32))
    (updated-content-hash (buff 32))
    (updated-metadata-content (string-utf8 256)))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash 
        (match (retrieve-document-record validated-unique-hash)
            existing-document-record 
            (match (validate-document-unique-hash updated-content-hash)
                validated-content-hash 
                (match (validate-document-metadata-content updated-metadata-content)
                    validated-metadata-content 
                    (if (is-eq (get document-owner existing-document-record) tx-sender)
                        (if (not (get verification-completed existing-document-record))
                            (ok (map-set verified-documents
                                { document-unique-hash: validated-unique-hash }
                                (merge existing-document-record
                                    {
                                        document-content-hash: validated-content-hash,
                                        document-metadata: validated-metadata-content,
                                        submission-timestamp: block-height,
                                        document-version: (+ (get document-version existing-document-record) u1),
                                        verification-completed: false
                                    })))
                            ERROR-VERIFICATION-ALREADY-COMPLETE)
                        ERROR-OWNER-ACCESS-DENIED)
                    error ERROR-INVALID-METADATA-FORMAT)
                error ERROR-INVALID-CONTENT-HASH)
            error ERROR-DOCUMENT-LOOKUP-FAILED)
        error ERROR-INVALID-HASH-FORMAT))

(define-public (mark-document-verified
    (document-unique-hash (buff 32)))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash
        (match (retrieve-document-record validated-unique-hash)
            existing-document-record 
            (match (get-verifier-permissions-status validated-unique-hash tx-sender)
                verifier-permissions 
                (if (get has-verification-rights verifier-permissions)
                    (if (not (get verification-completed existing-document-record))
                        (ok (map-set verified-documents
                            { document-unique-hash: validated-unique-hash }
                            (merge existing-document-record
                                {
                                    verification-status: DOCUMENT-STATUS-VERIFIED,
                                    document-verifier: (some tx-sender),
                                    verification-completed: true
                                })))
                        ERROR-VERIFICATION-ALREADY-COMPLETE)
                    ERROR-PERMISSION-DENIED)
                error ERROR-PERMISSION-DENIED)
            error ERROR-DOCUMENT-LOOKUP-FAILED)
        error ERROR-INVALID-HASH-FORMAT))

(define-public (set-verifier-access-rights
    (document-unique-hash (buff 32))
    (verifier-address principal)
    (grant-view-access bool)
    (grant-verification-rights bool))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash
        (match (retrieve-document-record validated-unique-hash)
            existing-document-record 
            (match (validate-verifier-address verifier-address)
                validated-verifier-address
                (if (is-eq (get document-owner existing-document-record) tx-sender)
                    (ok (map-set document-permissions
                        { document-unique-hash: validated-unique-hash, verifier-address: validated-verifier-address }
                        { 
                            has-view-access: grant-view-access, 
                            has-verification-rights: grant-verification-rights 
                        }))
                    ERROR-OWNER-ACCESS-DENIED)
                error ERROR-INVALID-VERIFIER-ADDRESS)
            error ERROR-DOCUMENT-LOOKUP-FAILED)
        error ERROR-INVALID-HASH-FORMAT))

(define-public (remove-verifier-access-rights
    (document-unique-hash (buff 32))
    (verifier-address principal))
    (match (validate-document-unique-hash document-unique-hash)
        validated-unique-hash
        (match (retrieve-document-record validated-unique-hash)
            existing-document-record 
            (match (validate-verifier-address verifier-address)
                validated-verifier-address
                (if (is-eq (get document-owner existing-document-record) tx-sender)
                    (ok (map-delete document-permissions
                        { document-unique-hash: validated-unique-hash, verifier-address: validated-verifier-address }))
                    ERROR-OWNER-ACCESS-DENIED)
                error ERROR-INVALID-VERIFIER-ADDRESS)
            error ERROR-DOCUMENT-LOOKUP-FAILED)
        error ERROR-INVALID-HASH-FORMAT))