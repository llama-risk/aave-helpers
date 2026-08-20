// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IRangeValidationModule
/// @notice Bound configuration surface of the RangeValidationModule, narrowed to what a proposal
///         needs.
/// @author Aave Labs
interface IRangeValidationModule {
  /// @notice Per-injection bounds applied to an agent's updates.
  /// @dev When a side is relative its bound is expressed in BPS (e.g. `5_00` for 5%); when absolute
  ///      it is in the units of the value being updated.
  struct RangeConfig {
    uint120 maxIncrease;
    uint120 maxDecrease;
    bool isIncreaseRelative;
    bool isDecreaseRelative;
  }

  /// @notice Sets the bounds applied to an agent's updates of a given type.
  function setDefaultRangeConfig(
    address agentHub,
    uint256 agentId,
    string memory updateType,
    RangeConfig memory rangeConfig
  ) external;

  /// @notice Reads the bounds currently applied to an agent's updates of a given type.
  function getDefaultRangeConfig(
    address agentHub,
    uint256 agentId,
    string memory updateType
  ) external view returns (RangeConfig memory);
}
