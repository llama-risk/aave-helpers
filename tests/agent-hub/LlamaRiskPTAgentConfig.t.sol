// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {LlamaRiskPTAgentConfig} from '../../src/agent-hub/LlamaRiskPTAgentConfig.sol';

/// @dev The values here are copied out of the first PT onboarding proposal, so what is worth
///      asserting is not that they are correct in the abstract but that they still say what that
///      proposal said. A silent edit to one of these changes how often a live agent may act, or how
///      far it may move a parameter, in every proposal that imports them.
contract LlamaRiskPTAgentConfigTest is Test {
  /// @dev The RiskOracle is constructed with these strings, the agents publish under them, and the
  ///      AgentHub registers against them. They are asserted literally because a rename here breaks
  ///      the agreement silently: registration succeeds, and nothing the agents publish is ever
  ///      matched.
  function test_updateTypesMatchWhatThePublishersUse() public pure {
    assertEq(LlamaRiskPTAgentConfig.DISCOUNT_UPDATE_TYPE, 'PendleDiscountRateUpdate');
    assertEq(LlamaRiskPTAgentConfig.EMODE_UPDATE_TYPE, 'EModeCategoryUpdate');
  }

  /// @dev Empty for a dedicated RiskOracle, which is what lets the agents and the offchain workflows
  ///      use the unsuffixed types without configuration. A non-empty default would silently change
  ///      what every future proposal registers.
  function test_suffixIsEmptyByDefault() public pure {
    assertEq(bytes(LlamaRiskPTAgentConfig.UPDATE_TYPE_SUFFIX).length, 0);
    assertEq(LlamaRiskPTAgentConfig.discountUpdateType(), 'PendleDiscountRateUpdate');
    assertEq(LlamaRiskPTAgentConfig.eModeUpdateType(), 'EModeCategoryUpdate');
  }

  /// @dev The eMode agent registers under one update type and injects three fields, each bounded
  ///      separately. A field missing from this list is a field left unbounded, which reads back as
  ///      a zero bound and rejects every update.
  function test_eModeBoundedUpdateTypesCoversEveryWrittenField() public pure {
    string[] memory updateTypes = LlamaRiskPTAgentConfig.eModeBoundedUpdateTypes();

    assertEq(updateTypes.length, 3, 'expected three bounded eMode fields');
    assertEq(updateTypes[0], 'EModeLTV');
    assertEq(updateTypes[1], 'EModeLiquidationThreshold');
    assertEq(updateTypes[2], 'EModeLiquidationBonus');
  }

  /// @dev An update outliving its injection window would let a stale value land as soon as the delay
  ///      reopens, so the expiration period is not independent of the delay.
  function test_expirationPeriodsMatchTheirDelays() public pure {
    assertEq(
      LlamaRiskPTAgentConfig.DISCOUNT_EXPIRATION_PERIOD,
      LlamaRiskPTAgentConfig.DISCOUNT_MINIMUM_DELAY,
      'discount expiration should match its delay'
    );
    assertEq(
      LlamaRiskPTAgentConfig.EMODE_EXPIRATION_PERIOD,
      LlamaRiskPTAgentConfig.EMODE_MINIMUM_DELAY,
      'eMode expiration should match its delay'
    );
  }

  function test_delaysMatchTheOnboardingProposal() public pure {
    assertEq(LlamaRiskPTAgentConfig.DISCOUNT_MINIMUM_DELAY, 2 days);
    assertEq(LlamaRiskPTAgentConfig.EMODE_MINIMUM_DELAY, 3 days);
  }

  /// @dev 1e16 is 100 bps in the 1e18 scale the discount rate uses; the eMode bound is in BPS.
  ///      Asserting the scale is what catches a bound edited in the wrong units, which would not
  ///      fail to compile and would widen or collapse the limit by orders of magnitude.
  function test_boundsMatchTheOnboardingProposal() public pure {
    assertEq(LlamaRiskPTAgentConfig.DISCOUNT_RANGE_ABS, 1e16, '100 bps in the 1e18 scale');
    assertEq(LlamaRiskPTAgentConfig.EMODE_RANGE_ABS_BPS, 50, '50 bps');
  }
}
