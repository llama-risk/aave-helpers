// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IACLManager} from 'aave-address-book/AaveV3.sol';
import {IAgentHub, IAgentConfigurator} from '../interfaces/IAgentHub.sol';
import {IRangeValidationModule} from '../interfaces/IRangeValidationModule.sol';

/// @title AgentHubOnboarding
/// @notice Builds the two calls a proposal makes to onboard a risk agent: granting it the Aave role
///         it injects updates with, and registering it in the AgentHub.
/// @dev `AgentRegistrationInput` has thirteen fields, seven of which are the same in every
///      onboarding done so far. Spelling all thirteen out per proposal is not just verbose, it puts
///      `isAgentPermissioned` and `restrictedMarkets` in front of an author who has no reason to
///      change them, in a struct where a wrong flag is a permission granted rather than a
///      compilation error. This library fixes those seven and takes the six that actually vary.
///
///      A proposal that genuinely needs a non-default flag should call `registerAgent` directly and
///      say why, rather than this library growing a parameter for it.
/// @author Aave Labs
library AgentHubOnboarding {
  /// @notice The fields of an agent registration that differ between onboardings.
  /// @param agentAddress The predeployed agent contract.
  /// @param riskOracle The RiskOracle the agent reads its update records from.
  /// @param admin The address allowed to manage this agent's configuration afterwards, normally the
  ///        governance executor.
  /// @param updateType The update type the agent answers to, matching what is published to the
  ///        RiskOracle.
  /// @param expirationPeriod How long an update stays eligible for injection.
  /// @param minimumDelay Minimum time between successful injections, per agent and market.
  /// @param agentContext Agent specific calldata, e.g. the ConfigEngine address for agents that
  ///        apply updates through it. Empty for agents that need none.
  /// @param allowedMarkets The markets this agent may inject updates for.
  struct AgentOnboardingInput {
    address agentAddress;
    address riskOracle;
    address admin;
    string updateType;
    uint256 expirationPeriod;
    uint256 minimumDelay;
    bytes agentContext;
    address[] allowedMarkets;
  }

  /// @notice Grants the agent `RISK_ADMIN` and registers it in the AgentHub.
  /// @dev The role has to be granted before the agent can apply anything; registration alone leaves
  ///      it unable to act. Both are done here so a proposal cannot land one without the other.
  /// @param aclManager The ACL manager of the pool the agent will act on.
  /// @param agentHub The AgentHub to register with.
  /// @param input The fields that vary between onboardings.
  /// @return agentId The id the hub allocated, read from the return value rather than assumed
  ///         because it is assigned at execution time from the current agent count.
  function registerAgentAndGrantRiskAdmin(
    IACLManager aclManager,
    address agentHub,
    AgentOnboardingInput memory input
  ) internal returns (uint256 agentId) {
    aclManager.addRiskAdmin(input.agentAddress);

    return
      IAgentHub(agentHub).registerAgent(
        IAgentConfigurator.AgentRegistrationInput({
          admin: input.admin,
          riskOracle: input.riskOracle,
          isAgentEnabled: true,
          isAgentPermissioned: false,
          isMarketsFromAgentEnabled: false,
          agentAddress: input.agentAddress,
          expirationPeriod: input.expirationPeriod,
          minimumDelay: input.minimumDelay,
          updateType: input.updateType,
          agentContext: input.agentContext,
          allowedMarkets: input.allowedMarkets,
          restrictedMarkets: new address[](0),
          permissionedSenders: new address[](0)
        })
      );
  }

  /// @notice Sets symmetric absolute bounds on an agent's updates of one type.
  /// @dev Absolute rather than relative, because a relative bound is a percentage of the last
  ///      injected value and a freshly registered agent id has none. A fresh id also inherits no
  ///      config at all, and the module reads a missing config as a zero bound, which rejects every
  ///      update: a new agent is unusable until this is called.
  /// @param rangeValidationModule The module holding the bounds.
  /// @param agentHub The AgentHub the agent is registered in.
  /// @param agentId The id returned by `registerAgentAndGrantRiskAdmin`.
  /// @param updateType The update type to bound. An agent that writes several fields is bounded per
  ///        field, so this is not always the agent's own registered update type.
  /// @param bound The maximum movement allowed in either direction, in the units of the value being
  ///        updated.
  function setAbsoluteRange(
    IRangeValidationModule rangeValidationModule,
    address agentHub,
    uint256 agentId,
    string memory updateType,
    uint120 bound
  ) internal {
    rangeValidationModule.setDefaultRangeConfig(
      agentHub,
      agentId,
      updateType,
      IRangeValidationModule.RangeConfig({
        maxIncrease: bound,
        maxDecrease: bound,
        isIncreaseRelative: false,
        isDecreaseRelative: false
      })
    );
  }

  /// @notice Applies the same absolute bound to several update types of one agent.
  /// @dev For agents writing several fields under one registration, where each field is bounded
  ///      separately but identically.
  function setAbsoluteRanges(
    IRangeValidationModule rangeValidationModule,
    address agentHub,
    uint256 agentId,
    string[] memory updateTypes,
    uint120 bound
  ) internal {
    for (uint256 i = 0; i < updateTypes.length; i++) {
      setAbsoluteRange(rangeValidationModule, agentHub, agentId, updateTypes[i], bound);
    }
  }
}
