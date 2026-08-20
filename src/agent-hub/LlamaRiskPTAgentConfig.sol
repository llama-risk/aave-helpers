// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title LlamaRiskPTAgentConfig
/// @notice The onboarding parameters shared by every LlamaRisk PT risk agent: the update types they
///         answer to, how long their updates stay injectable, how often they may inject, and the
///         bounds their updates are held to.
/// @dev These do not vary per asset. Onboarding a second PT changes the market address and the eMode
///      ids and nothing here, so a proposal that redeclares them is copying values rather than
///      choosing them.
///
///      The update type strings matter more than they look. The RiskOracle is constructed with them,
///      the agents publish under them, and the AgentHub registers against them, so all three layers
///      agree only if the same literal is written in three repositories. Reading them from one place
///      makes that agreement structural instead of a matter of typing carefully.
/// @author LlamaRisk
library LlamaRiskPTAgentConfig {
  // ============================================================================================
  // Update types
  // ============================================================================================

  /// @notice The update type the discount rate agent answers to.
  string internal constant DISCOUNT_UPDATE_TYPE = 'PendleDiscountRateUpdate';

  /// @notice The update type the eMode agent answers to.
  string internal constant EMODE_UPDATE_TYPE = 'EModeCategoryUpdate';

  /// @notice Appended to the update types when a RiskOracle is shared between stacks.
  /// @dev Empty for a RiskOracle dedicated to the LlamaGuard stack, which is what lets the agents
  ///      and the offchain workflows use the unsuffixed types without configuration.
  string internal constant UPDATE_TYPE_SUFFIX = '';

  /// @notice The eMode fields the eMode agent writes, each bounded separately.
  /// @dev The agent registers under one update type but injects three, and a field left unbounded
  ///      reads back as a zero bound and rejects every update, so these travel together.
  function eModeBoundedUpdateTypes() internal pure returns (string[] memory updateTypes) {
    updateTypes = new string[](3);
    updateTypes[0] = 'EModeLTV';
    updateTypes[1] = 'EModeLiquidationThreshold';
    updateTypes[2] = 'EModeLiquidationBonus';
  }

  // ============================================================================================
  // Timing
  // ============================================================================================

  /// @notice Minimum time between successful discount rate injections, per market.
  uint256 internal constant DISCOUNT_MINIMUM_DELAY = 2 days;

  /// @notice Minimum time between successful eMode injections, per market.
  uint256 internal constant EMODE_MINIMUM_DELAY = 3 days;

  /// @notice How long a discount rate update stays eligible for injection.
  /// @dev Matched to the minimum delay: an update that outlives the delay would let a stale value
  ///      land immediately after the window reopens.
  uint256 internal constant DISCOUNT_EXPIRATION_PERIOD = 2 days;

  /// @notice How long an eMode update stays eligible for injection.
  uint256 internal constant EMODE_EXPIRATION_PERIOD = 3 days;

  // ============================================================================================
  // Bounds
  // ============================================================================================

  /// @notice Maximum discount rate movement per injection, in either direction.
  /// @dev 1e16 is 100 bps in the 1e18 scale the discount rate is expressed in. Absolute rather than
  ///      relative, because a relative bound is a percentage of the last injected value and a fresh
  ///      agent id has none.
  uint120 internal constant DISCOUNT_RANGE_ABS = 1e16;

  /// @notice Maximum eMode field movement per injection, in either direction, in BPS.
  uint120 internal constant EMODE_RANGE_ABS_BPS = 50;

  // ============================================================================================
  // Composed
  // ============================================================================================

  /// @notice The discount rate agent's update type, suffixed.
  function discountUpdateType() internal pure returns (string memory) {
    return string.concat(DISCOUNT_UPDATE_TYPE, UPDATE_TYPE_SUFFIX);
  }

  /// @notice The eMode agent's update type, suffixed.
  function eModeUpdateType() internal pure returns (string memory) {
    return string.concat(EMODE_UPDATE_TYPE, UPDATE_TYPE_SUFFIX);
  }
}
