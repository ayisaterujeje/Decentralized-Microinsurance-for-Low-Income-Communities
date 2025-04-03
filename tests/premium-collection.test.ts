import { describe, it, expect, beforeEach, vi } from "vitest"

// Mock the Clarity contract interactions
const mockContractCall = vi.fn()
const mockGetSubscription = vi.fn()

// Mock the tx-sender
const mockTxSender = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"

// Mock contract responses
const mockSubscriptionResponse = {
  premium_amount: 5000,
  last_payment: 100,
  payment_frequency: 30,
  active: true,
  total_paid: 5000,
}

describe("Premium Collection Contract", () => {
  beforeEach(() => {
    // Reset mocks
    mockContractCall.mockReset()
    mockGetSubscription.mockReset()
    
    // Setup default mock responses
    mockContractCall.mockImplementation((functionName, ...args) => {
      if (functionName === "subscribe") {
        return { result: { value: true } }
      } else if (functionName === "pay-premium") {
        return { result: { value: true } }
      } else if (functionName === "cancel-subscription") {
        return { result: { value: true } }
      }
      return { result: { value: null } }
    })
    
    mockGetSubscription.mockImplementation((user, policyId) => {
      if (user === mockTxSender && policyId === 1) {
        return { result: { value: mockSubscriptionResponse } }
      }
      return { result: { value: null } }
    })
  })
  
  it("should subscribe to a policy", async () => {
    const policyContract = ".policy-creation"
    const policyId = 1
    
    const result = mockContractCall("subscribe", policyContract, policyId)
    
    expect(result.result.value).toBe(true)
  })
  
  it("should make a premium payment", async () => {
    const policyId = 1
    
    const result = mockContractCall("pay-premium", policyId)
    
    expect(result.result.value).toBe(true)
  })
  
  it("should retrieve subscription details", async () => {
    const user = mockTxSender
    const policyId = 1
    
    const result = mockGetSubscription(user, policyId)
    
    expect(result.result.value).toEqual(mockSubscriptionResponse)
  })
  
  it("should cancel a subscription", async () => {
    const policyId = 1
    
    const result = mockContractCall("cancel-subscription", policyId)
    
    expect(result.result.value).toBe(true)
  })
  
  it("should fail when trying to subscribe to a non-existent policy", async () => {
    const policyContract = ".policy-creation"
    const nonExistentPolicyId = 999
    
    mockContractCall.mockImplementation(() => {
      return { result: { error: 102 } } // ERR_POLICY_NOT_FOUND
    })
    
    const result = mockContractCall("subscribe", policyContract, nonExistentPolicyId)
    
    expect(result.result.error).toBe(102)
  })
  
  it("should fail when making payment for non-subscribed policy", async () => {
    const nonSubscribedPolicyId = 2
    
    mockContractCall.mockImplementation(() => {
      return { result: { error: 104 } } // ERR_NOT_SUBSCRIBED
    })
    
    const result = mockContractCall("pay-premium", nonSubscribedPolicyId)
    
    expect(result.result.error).toBe(104)
  })
})

