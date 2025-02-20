# Document Verification Smart Contract

## Overview
A secure and flexible smart contract for managing document verification on the Stacks blockchain. This contract enables document owners to submit documents for verification, manage verifier access rights, and maintain a transparent verification process.

## Features

- Document submission with content hash and metadata
- Secure document version control
- Granular verifier permission management
- Document status tracking
- Enhanced error handling and input validation

## Core Functions

### Document Management

1. `submit-new-document`
   - Submit a new document for verification
   - Parameters:
     - `document-unique-hash`: Unique identifier for the document (32-byte buffer)
     - `document-content-hash`: Hash of the document content (32-byte buffer)
     - `document-metadata-content`: Additional document metadata (UTF-8 string, max 256 chars)

2. `update-document-content`
   - Update an existing document's content and metadata
   - Only available before verification is complete
   - Automatically increments document version

3. `mark-document-verified`
   - Mark a document as verified
   - Can only be called by authorized verifiers
   - Sets verification status to "VERIFIED"

### Access Control

1. `set-verifier-access-rights`
   - Grant or modify verifier permissions
   - Control view access and verification rights
   - Only document owner can set permissions

2. `remove-verifier-access-rights`
   - Remove a verifier's access to a document
   - Only document owner can remove permissions

### Read-Only Functions

1. `get-document-details`
   - Retrieve complete document information
   - Returns document record with all metadata

2. `get-verifier-permissions-status`
   - Check current permissions for a specific verifier
   - Returns view and verification rights status

## Document States

- **DOCUMENT_STATUS_PENDING**: Initial state after document submission
- **DOCUMENT_STATUS_VERIFIED**: Final state after successful verification

## Error Codes

- `ERR_OWNER_ACCESS_DENIED (u100)`: Unauthorized access attempt
- `ERR_DOCUMENT_ALREADY_EXISTS (u101)`: Duplicate document submission
- `ERR_DOCUMENT_LOOKUP_FAILED (u102)`: Document not found
- `ERR_VERIFICATION_ALREADY_COMPLETE (u103)`: Attempt to modify verified document
- `ERR_INVALID_HASH_FORMAT (u104)`: Invalid document hash format
- `ERR_INVALID_CONTENT_HASH (u105)`: Invalid content hash
- `ERR_INVALID_METADATA_FORMAT (u106)`: Invalid metadata format
- `ERR_INVALID_VERIFIER_ADDRESS (u107)`: Invalid verifier address
- `ERR_INVALID_INPUT_PARAMETER (u108)`: Invalid input parameters
- `ERR_PERMISSION_DENIED (u109)`: Insufficient permissions

## Security Features

- Strict input validation for all parameters
- Separate permission management for viewing and verification
- Version control for document updates
- Clear ownership and access control model
- Prevention of self-verification
- Protection against unauthorized modifications

## Data Structure

Documents are stored with the following information:
- Document owner address
- Content hash
- Submission timestamp
- Verification status
- Verifier address (if verified)
- Document metadata
- Version number
- Verification completion status

## Best Practices for Usage

1. Always validate document hashes before submission
2. Maintain secure off-chain storage for actual document content
3. Implement proper error handling for all contract interactions
4. Carefully manage verifier permissions
5. Keep track of document versions when making updates

## Technical Requirements

- Stacks blockchain compatibility
- 32-byte buffer support for document hashes
- UTF-8 string support for metadata (max 256 characters)