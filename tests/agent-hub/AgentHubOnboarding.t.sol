// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';

import {AgentHubOnboarding} from '../../src/agent-hub/AgentHubOnboarding.sol';
import {AgentHubTestBase} from '../../src/agent-hub/AgentHubTestBase.sol';
import {IAgentHub} from '../../src/interfaces/IAgentHub.sol';
import {IRangeValidationModule} from '../../src/interfaces/IRangeValidationModule.sol';

/// @dev Exercises the onboarding helpers against the live AgentHub rather than a mock, so the
///      thirteen field struct is filled the way the real contract reads it back. Pinned, because
///      these assert the helpers' own behaviour and nothing about them should change with the head
///      of the chain.
contract AgentHubOnboardingTest is AgentHubTestBase {
  uint256 internal constant FORK_BLOCK = 25789439;

  IAgentHub internal constant AGENT_HUB = IAgentHub(MiscEthereum.AGENT_HUB);
  IRangeValidationModule internal constant RANGE_MODULE =
    IRangeValidationModule(MiscEthereum.RANGE_VALIDATION_MODULE);

  /// @dev Any address works: the helpers never call into the agent, they only register its address.
  address internal constant AGENT = address(0xA6E7);
  address internal constant RISK_ORACLE = address(0x0AC1E);

  string internal constant UPDATE_TYPE = 'MockAgentUpdate';
  uint256 internal constant EXPIRATION_PERIOD = 2 days;
  uint256 internal constant MINIMUM_DELAY = 1 days;
  uint120 internal constant BOUND = 50;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
  }

  // ============================================================================================
  // registerAgentAndGrantRiskAdmin
  // ============================================================================================

  /// @dev The whole point of the helper: the six varying fields land where the payload put them, and
  ///      the seven fixed ones land on their defaults.
  function test_registerAgentAndGrantRiskAdmin() public {
    uint256 expectedId = AGENT_HUB.getAgentCount();

    address[] memory markets = new address[](1);
    markets[0] = AaveV3EthereumAssets.WETH_UNDERLYING;

    uint256 agentId = _register(markets, '');

    assertEq(agentId, expectedId, 'agent id should be the pre-call agent count');

    assertAgentOnboarded(
      AGENT_HUB,
      AaveV3Ethereum.ACL_MANAGER,
      agentId,
      ExpectedAgent({
        agentAddress: AGENT,
        riskOracle: RISK_ORACLE,
        admin: AaveV3Ethereum.ACL_ADMIN,
        updateType: UPDATE_TYPE,
        expirationPeriod: EXPIRATION_PERIOD,
        minimumDelay: MINIMUM_DELAY,
        allowedMarkets: markets
      })
    );
  }

  /// @dev The role grant is half of what the helper exists to keep together: registering without it
  ///      leaves an agent that is configured and cannot act.
  function test_registerAgentGrantsRiskAdminThatWasNotHeldBefore() public {
    assertFalse(
      AaveV3Ethereum.ACL_MANAGER.isRiskAdmin(AGENT),
      'agent should start without the role'
    );

    _register(new address[](0), '');

    assertTrue(AaveV3Ethereum.ACL_MANAGER.isRiskAdmin(AGENT), 'agent should hold the role');
  }

  /// @dev Agents applying updates through the ConfigEngine carry its address as context; agents that
  ///      need none carry empty bytes. Both have to survive the helper untouched.
  function test_registerAgentPreservesAgentContext() public {
    bytes memory context = abi.encode(AaveV3Ethereum.CONFIG_ENGINE);

    uint256 agentId = _register(new address[](0), context);

    assertEq(AGENT_HUB.getAgentContext(agentId), context, 'agent context');
  }

  /// @dev Ids are allocated at execution time, so a payload registering several agents cannot assume
  ///      them and the helper has to return what the hub assigned.
  function test_registerAgentReturnsSequentialIds() public {
    uint256 first = _register(new address[](0), '');
    uint256 second = _register(new address[](0), '');

    assertEq(second, first + 1, 'ids should increment');
  }

  // ============================================================================================
  // setAbsoluteRange
  // ============================================================================================

  /// @dev A fresh id starts unbounded, which the module reads as a zero bound and therefore rejects
  ///      every update. Asserting the before state is what proves the helper is the cause of the
  ///      after state.
  function test_setAbsoluteRangeConfiguresAFreshAgent() public {
    uint256 agentId = _register(new address[](0), '');

    assertRangeUnset(RANGE_MODULE, address(AGENT_HUB), agentId, UPDATE_TYPE);

    vm.prank(AaveV3Ethereum.ACL_ADMIN);
    AgentHubOnboarding.setAbsoluteRange(
      RANGE_MODULE,
      address(AGENT_HUB),
      agentId,
      UPDATE_TYPE,
      BOUND
    );

    assertAbsoluteRange(RANGE_MODULE, address(AGENT_HUB), agentId, UPDATE_TYPE, BOUND);
  }

  /// @dev An agent writing several fields is bounded per field. The loop is the helper's reason to
  ///      exist: bounding three of four types leaves the fourth rejecting everything.
  function test_setAbsoluteRangesBoundsEveryType() public {
    uint256 agentId = _register(new address[](0), '');

    string[] memory updateTypes = new string[](3);
    updateTypes[0] = 'EModeLTV';
    updateTypes[1] = 'EModeLiquidationThreshold';
    updateTypes[2] = 'EModeLiquidationBonus';

    // One call per update type, so the prank has to span the loop.
    vm.startPrank(AaveV3Ethereum.ACL_ADMIN);
    AgentHubOnboarding.setAbsoluteRanges(
      RANGE_MODULE,
      address(AGENT_HUB),
      agentId,
      updateTypes,
      BOUND
    );
    vm.stopPrank();

    assertAbsoluteRanges(RANGE_MODULE, address(AGENT_HUB), agentId, updateTypes, BOUND);
  }

  /// @dev Bounds are symmetric and absolute. Relative bounds are measured against a last injected
  ///      value a fresh id does not have.
  function test_setAbsoluteRangeIsSymmetricAndAbsolute() public {
    uint256 agentId = _register(new address[](0), '');

    vm.prank(AaveV3Ethereum.ACL_ADMIN);
    AgentHubOnboarding.setAbsoluteRange(
      RANGE_MODULE,
      address(AGENT_HUB),
      agentId,
      UPDATE_TYPE,
      BOUND
    );

    IRangeValidationModule.RangeConfig memory config = RANGE_MODULE.getDefaultRangeConfig(
      address(AGENT_HUB),
      agentId,
      UPDATE_TYPE
    );

    assertEq(config.maxIncrease, config.maxDecrease, 'bounds should be symmetric');
    assertFalse(config.isIncreaseRelative, 'increase should be absolute');
    assertFalse(config.isDecreaseRelative, 'decrease should be absolute');
  }

  // ============================================================================================
  // Helpers
  // ============================================================================================

  /// @dev Runs the onboarding as the executor, which is the account a payload executes under.
  function _register(
    address[] memory allowedMarkets,
    bytes memory agentContext
  ) internal returns (uint256 agentId) {
    vm.startPrank(AaveV3Ethereum.ACL_ADMIN);
    agentId = AgentHubOnboarding.registerAgentAndGrantRiskAdmin(
      AaveV3Ethereum.ACL_MANAGER,
      address(AGENT_HUB),
      AgentHubOnboarding.AgentOnboardingInput({
        agentAddress: AGENT,
        riskOracle: RISK_ORACLE,
        admin: AaveV3Ethereum.ACL_ADMIN,
        updateType: UPDATE_TYPE,
        expirationPeriod: EXPIRATION_PERIOD,
        minimumDelay: MINIMUM_DELAY,
        agentContext: agentContext,
        allowedMarkets: allowedMarkets
      })
    );
    vm.stopPrank();
  }
}
