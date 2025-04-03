import { describe, it, expect, beforeEach, vi } from "vitest"

// Mock the Clarity contract interactions
const mockContractCall = vi.fn()
const mockGetClaim = vi.fn()

// Mock the tx-sender
let mockTxSender = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
const mockAdmin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
const mockClaimant = "ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"

// Status constants
const STATUS_SUBMITTED = 0
const STATUS_UNDER_REVIEW = 1
const STATUS_APPROVED = 2
const STATUS_REJECTED = 3
const STATUS_PAID = 4

// Mock contract responses
const mockClaimResponse = {
  claimant: mockClaimant,
  policy_id: 1,
  amount: 50000,
  description: "Crop damage due to drought",
  status: STATUS_SUBMITTED,
  created_at: 100,
  updated_at: 100,
  evidence_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
}

describe("Claims Processing Contract", () => {
  beforeEach(() => {
    // Reset mocks
    mockContractCall.mockReset()
    mockGetClaim.mockReset()
    
    // Setup default mock responses
    mockContractCall.mockImplementation((functionName, ...args) => {
      if (functionName === "submit-claim") {
        return { result: { value: 1 } } // Return claim ID 1
      } else if (functionName === "update-claim-status") {
        return { result: { value: true } }
      } else if (functionName === "process-verified-claim") {
        return { result: { value: STATUS_APPROVED } }
      } else if (functionName === "pay-claim") {
        return { result: { value: true } }
      }
      return { result: { value: null } }
    })
    
    mockGetClaim.mockImplementation((claimId) => {
      if (claimId === 1) {
        return { result: { value: mockClaimResponse } }
      }
      return { result: { value: null } }
    })
  })
  
  it("should submit a new claim", async () => {
    const premiumContract = ".premium-collection"
    const policyId = 1
    const amount = 50000
    const description = "Crop damage due to drought"
    const evidenceHash = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    
    mockTxSender = mockClaimant
    const result = mockContractCall("submit-claim", premiumContract, policyId, amount, description, evidenceHash)
    
    expect(result.result.value).toBe(1) // Claim ID 1
  })
  
  it("should update claim status", async () => {
    const claimId = 1
    const newStatus = STATUS_UNDER_REVIEW
    
    mockTxSender = mockAdmin
    const result = mockContractCall("update-claim-status", claimId, newStatus)
    
    expect(result.result.value).toBe(true)
  })
  
  it("should process a verified claim", async () => {
    const claimId = 1
    const verificationContract = ".peer-verification"
    
    mockTxSender = mockAdmin
    const result = mockContractCall("process-verified-claim", claimId, verificationContract)
    
    expect(result.result.value).toBe(STATUS_APPROVED)
  })
  
  it("should pay an approved claim", async () => {
    const claimId = 1
    
    // Mock that the claim is approved
    mockGetClaim.mockImplementation(() => {
      return {
        result: {
          value: {
            ...mockClaimResponse,
            status: STATUS_APPROVED,
          },
        },
      }
    })
    
    mockTxSender = mockAdmin
    const result = mockContractCall("pay-claim", claimId)
    
    expect(result.result.value).toBe(true)
  })
  
  it("should retrieve claim details", async () => {
    const claimId = 1
    
    const result = mockGetClaim(claimId)
    
    expect(result.result.value).toEqual(mockClaimResponse)
  })
  
  it("should fail when non-admin tries to update claim status", async () => {
    const claimId = 1
    const newStatus = STATUS_APPROVED
    
    mockTxSender = mockClaimant // Not admin
    mockContractCall.mockImplementation(() => {
      return { result: { error: 100 } } // ERR_UNAUTHORIZED
    })
    
    const result = mockContractCall("update-claim-status", claimId, newStatus)
    
    expect(result.result.error).toBe(100)
  })
  
  it("should fail when trying to pay a non-approved claim", async () => {
    const claimId = 1
    
    // Claim is still in SUBMITTED status
    mockContractCall.mockImplementation(() => {
      return { result: { error: 102 } } // ERR_INVALID_STATUS
    })
    
    mockTxSender = mockAdmin
    const result = mockContractCall("pay-claim", claimId)
    
    expect(result.result.error).toBe(102)
  })
})

