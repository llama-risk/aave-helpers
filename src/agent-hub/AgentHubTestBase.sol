// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IACLManager} from 'aave-address-book/AaveV3.sol';
import {IAgentHub} from '../interfaces/IAgentHub.sol';
import {IRangeValidationModule} from '../interfaces/IRangeValidationModule.sol';

/// @title AgentHubTestBase
/// @notice Assertions every agent onboarding proposal repeats: that the agent was registered with
///         the configuration the payload declared, that it holds the Aave role it needs, and that
///         its update bounds were set.
/// @dev These are properties of the onboarding itself, not of any one agent, so a proposal that
///      inherits this is left writing only what is specific to the asset it onboards.
///
///      Two of them are worth stating plainly, because they are the ones that fail quietly. A fresh
///      agent id inherits no range config, and the module reads a missing config as a zero bound, so
///      an agent registered without one is registered and permanently unable to inject: asserting
///      the config exists is asserting the agent works at all. And a registration that lands without
///      the ACL role is the same failure in the other direction, which is why
///      `assertAgentOnboarded` checks both rather than leaving the role to a separate test that can
///      be forgotten.
/// @author Aave Labs
abstract contract AgentHubTestBase is Test {
  /// @notice The configuration a proposal declared for an agent, as it should read back.
  /// @param agentAddress The agent contract expected under this id.
  /// @param riskOracle The RiskOracle the agent should read from.
  /// @param admin The address expected to manage the agent afterwards.
  /// @param updateType The update type the agent should answer to.
  /// @param expirationPeriod Expected eligibility window for an update.
  /// @param minimumDelay Expected minimum time between injections.
  /// @param allowedMarkets The markets the agent should be allowed to act on, in order.
  struct ExpectedAgent {
    address agentAddress;
    address riskOracle;
    address admin;
    string updateType;
    uint256 expirationPeriod;
    uint256 minimumDelay;
    address[] allowedMarkets;
  }

  /// @notice Asserts an agent is registered as declared, holds `RISK_ADMIN`, and is not restricted.
  /// @dev The single call a proposal test makes per agent. Use the narrower assertions below when a
  ///      proposal deliberately departs from this shape.
  function assertAgentOnboarded(
    IAgentHub agentHub,
    IACLManager aclManager,
    uint256 agentId,
    ExpectedAgent memory expected
  ) internal view {
    assertAgentRegistered(agentHub, agentId, expected);
    assertAgentIsRiskAdmin(aclManager, expected.agentAddress);
    assertNoRestrictedMarkets(agentHub, agentId);
  }

  /// @notice Asserts the agent's stored configuration matches what the payload declared.
  function assertAgentRegistered(
    IAgentHub agentHub,
    uint256 agentId,
    ExpectedAgent memory expected
  ) internal view {
    assertEq(agentHub.getAgentAddress(agentId), expected.agentAddress, 'agent address');
    assertEq(agentHub.getRiskOracle(agentId), expected.riskOracle, 'risk oracle');
    assertEq(agentHub.getAgentAdmin(agentId), expected.admin, 'agent admin');
    assertEq(agentHub.getUpdateType(agentId), expected.updateType, 'update type');
    assertEq(agentHub.getExpirationPeriod(agentId), expected.expirationPeriod, 'expiration period');
    assertEq(agentHub.getMinimumDelay(agentId), expected.minimumDelay, 'minimum delay');

    address[] memory allowedMarkets = agentHub.getAllowedMarkets(agentId);
    assertEq(allowedMarkets.length, expected.allowedMarkets.length, 'allowed markets length');
    for (uint256 i = 0; i < expected.allowedMarkets.length; i++) {
      assertEq(allowedMarkets[i], expected.allowedMarkets[i], 'allowed market');
    }
  }

  /// @notice Asserts the agent holds the Aave role it injects updates with.
  /// @dev Registration and the role grant are independent; an agent with one and not the other is
  ///      registered and inert.
  function assertAgentIsRiskAdmin(IACLManager aclManager, address agentAddress) internal view {
    assertTrue(aclManager.isRiskAdmin(agentAddress), 'agent is not risk admin');
  }

  /// @notice Asserts the agent carries no market restrictions.
  function assertNoRestrictedMarkets(IAgentHub agentHub, uint256 agentId) internal view {
    assertEq(agentHub.getRestrictedMarkets(agentId).length, 0, 'unexpected restricted markets');
  }

  /// @notice Asserts an update type is bounded by symmetric absolute bounds of `bound`.
  /// @dev Also asserts the bounds are absolute: a relative bound on a fresh agent id is measured
  ///      against a last injected value that does not exist.
  function assertAbsoluteRange(
    IRangeValidationModule rangeValidationModule,
    address agentHub,
    uint256 agentId,
    string memory updateType,
    uint120 bound
  ) internal view {
    IRangeValidationModule.RangeConfig memory config = rangeValidationModule.getDefaultRangeConfig(
      agentHub,
      agentId,
      updateType
    );

    assertEq(config.maxIncrease, bound, 'max increase');
    assertEq(config.maxDecrease, bound, 'max decrease');
    assertFalse(config.isIncreaseRelative, 'increase should be absolute');
    assertFalse(config.isDecreaseRelative, 'decrease should be absolute');
  }

  /// @notice Asserts every listed update type is bounded, and that none was left unset.
  /// @dev The failure this catches is an agent that writes several fields where only some were
  ///      bounded: the unbounded ones read back as a zero config and reject every update.
  function assertAbsoluteRanges(
    IRangeValidationModule rangeValidationModule,
    address agentHub,
    uint256 agentId,
    string[] memory updateTypes,
    uint120 bound
  ) internal view {
    for (uint256 i = 0; i < updateTypes.length; i++) {
      assertAbsoluteRange(rangeValidationModule, agentHub, agentId, updateTypes[i], bound);
    }
  }

  /// @notice Asserts an update type has no bounds configured, and is therefore unusable.
  /// @dev The state a fresh agent id starts in. Useful to assert before a payload runs, so that a
  ///      passing `assertAbsoluteRange` afterwards is known to be the payload's doing rather than
  ///      configuration that was already there.
  function assertRangeUnset(
    IRangeValidationModule rangeValidationModule,
    address agentHub,
    uint256 agentId,
    string memory updateType
  ) internal view {
    IRangeValidationModule.RangeConfig memory config = rangeValidationModule.getDefaultRangeConfig(
      agentHub,
      agentId,
      updateType
    );

    assertEq(config.maxIncrease, 0, 'expected no bound');
    assertEq(config.maxDecrease, 0, 'expected no bound');
  }
}
