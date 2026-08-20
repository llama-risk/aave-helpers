// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IAgentConfigurator
/// @notice Registration surface of the AgentHub, narrowed to what a proposal needs.
/// @author Aave Labs
interface IAgentConfigurator {
  /// @notice Everything the AgentHub stores about an agent at registration time.
  /// @dev Mirrors the struct in `aave-agent-hub`. Declared here because that repo is not a
  ///      dependency of this one, in the same way the payload interfaces under `src/interfaces`
  ///      are.
  struct AgentRegistrationInput {
    address admin;
    address riskOracle;
    bool isAgentEnabled;
    bool isAgentPermissioned;
    bool isMarketsFromAgentEnabled;
    address agentAddress;
    uint256 expirationPeriod;
    uint256 minimumDelay;
    string updateType;
    bytes agentContext;
    address[] allowedMarkets;
    address[] restrictedMarkets;
    address[] permissionedSenders;
  }
}

/// @title IAgentHub
/// @notice Registration surface of the AgentHub, narrowed to what a proposal needs.
/// @author Aave Labs
interface IAgentHub {
  /// @notice Registers an agent and returns the id allocated to it.
  /// @dev The id is assigned at execution time from the current agent count, so it cannot be known
  ///      when the payload is written.
  function registerAgent(
    IAgentConfigurator.AgentRegistrationInput memory input
  ) external returns (uint256);

  /// @notice Number of agents registered so far, and therefore the id the next one receives.
  function getAgentCount() external view returns (uint256);

  /// @notice The agent contract registered under `agentId`.
  function getAgentAddress(uint256 agentId) external view returns (address);

  /// @notice The address allowed to manage `agentId`'s configuration.
  function getAgentAdmin(uint256 agentId) external view returns (address);

  /// @notice The RiskOracle `agentId` reads its update records from.
  function getRiskOracle(uint256 agentId) external view returns (address);

  /// @notice The update type `agentId` answers to.
  function getUpdateType(uint256 agentId) external view returns (string memory);

  /// @notice How long an update stays eligible for injection.
  function getExpirationPeriod(uint256 agentId) external view returns (uint256);

  /// @notice Minimum time between successful injections for `agentId`.
  function getMinimumDelay(uint256 agentId) external view returns (uint256);

  /// @notice Markets `agentId` may inject updates for.
  function getAllowedMarkets(uint256 agentId) external view returns (address[] memory);

  /// @notice Markets `agentId` may never inject updates for.
  function getRestrictedMarkets(uint256 agentId) external view returns (address[] memory);

  /// @notice Agent specific calldata stored at registration, e.g. a ConfigEngine address.
  function getAgentContext(uint256 agentId) external view returns (bytes memory);
}
