// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract StakingPool is ReentrancyGuard {
    IERC20Metadata public stakingToken; // staking token address
    IERC20Metadata public rewardToken; // reward token address
    uint256 public rewardRatePerSecond; // per second emission rate
    uint256 public rewardPerToken; //per token return
    uint256 public totalStaked; //total staked tokens
    uint256 public lastRewardTime; //last reward was calculated at
    uint256 public poolEndTime; //epoch of end time
    uint256 public lockinDuration; // in seconds
    uint256 public totalPoolRewards; // AMOUNT OF TOKENS LEFT FOR THE DISTRIBUTION
    uint256 public totalRewardsLeft; //TOT REWARDS ADDED
    uint256 public allStakeLength; //total entries in staking array
    address public poolCreator; //pool creator's address
    uint256 public createdAt; //pool created at
    uint256 public updatedAt; //pool created at
    uint256 public precisionFactor; //precision factor of the token // Wei
    uint256 public tokenDecimalFactor; //precision factor of the token // Gwei
    uint256 public deci; //precision of token

    struct AllStake {
        uint256 amount; //amount staked
        uint256 accuRewards; // accumalated rewards
        bool hasUnstaked; // Flag to indicate if the user has completely unstaked
        bool isPostExpiry; // Flag to indicate if it is an unstake record post expiry
        uint256 unstakeTime; //unstaking time
        uint256 lastUpdated; //pseudo field to track last update
        uint256 currentRewardRate; //current reward rate
        uint256 totalStakedInPool; //total amount staked in pool, including current staking
        address add; //address of the staker
        bytes32 uuid; // Unique identifier for the stake
        bytes32 stakeUuid;
        uint256 createdAt;
    }

    mapping(bytes32 => AllStake) public stakesUid;
    AllStake[] private allStakers;

    constructor(
        address _stakingToken,
        uint256 _poolDurationDays,
        uint256 _lockinDurationDays
    ) {
        require(_poolDurationDays > 0, "Pool duration cannot be zero");
        stakingToken = IERC20Metadata(_stakingToken);
        rewardToken = IERC20Metadata(_stakingToken);
        lastRewardTime = block.timestamp;
        poolEndTime = block.timestamp + (_poolDurationDays * 1 minutes); //need to change
        lockinDuration = _lockinDurationDays * 1 days;
        poolCreator = msg.sender;
        precisionFactor = 10**18; // Set precision factor to a high value
        tokenDecimalFactor = 10**(18 - stakingToken.decimals());
        deci = 10**stakingToken.decimals();
        createdAt  = block.timestamp;
    }

    event Unstake(address indexed user, uint256 amount, uint256 rewards);
    event Logg(string message, uint256);
    event RewardsAdded(uint256 totalPoolReward);

    //ADD REWARDS TO POOL FOR DISTRIBUTION
    function addRewards(uint256 _rewardsToAdd) external nonReentrant {
        require(
            rewardToken.transferFrom(msg.sender, address(this), _rewardsToAdd),
            "Reward transfer failed"
        );
        require(msg.sender == poolCreator, "only pool creator can add funds");
        require(totalPoolRewards == 0, "Already added the reward token to the contract.");
        totalPoolRewards += _rewardsToAdd * precisionFactor;
        totalRewardsLeft += _rewardsToAdd * precisionFactor;
        // console.log("total pool rewards : ", totalPoolRewards);
        rewardRatePerSecond = currTokRet();
        // console.log("current reward rate per second: ",rewardRatePerSecond);
    }

    //UPDATE REWARDS TO POOL
    function updateStakingPool(uint256 _rewards, uint256 _poolDuration) external nonReentrant {
        // Ensure rewards amount is positive
        require(_rewards > 0, "Rewards must be greater than zero.");
        // Ensure the function caller is the pool creator
        require(msg.sender == poolCreator, "Only the pool creator can update the pool.");
        // Ensure that there are already rewards in the pool
        require(totalPoolRewards > 0, "No rewards have been added to the pool.");
        // Ensure that the pool has not expired
        require(block.timestamp < poolEndTime, "Pool is expired.");
        // Transfer rewards from the caller to the contract
        require(rewardToken.transferFrom(msg.sender, address(this), _rewards), "Reward transfer failed.");
        // Update total pool rewards and rewards left
        totalPoolRewards += _rewards * precisionFactor;
        totalRewardsLeft += _rewards * precisionFactor;
        // Update the timestamp when the pool was last updated
        updatedAt  = block.timestamp;

        // Extend the pool duration if specified
        if(_poolDuration > 0) {
            poolEndTime +=  _poolDuration * 1 minutes; //need to change
            console.log("pool updated with ",_poolDuration);
        }

        // Recalculate reward rate per second
        rewardRatePerSecond += _rewards * precisionFactor / (poolEndTime - block.timestamp);

        // If there are stakers, update the pool with new rewards
        if(allStakers.length > 0) {
            updatePool(_rewards);
            console.log("update staking records");
        }

    }


    function updatePool(uint256 _rewards) internal {
        bytes32 uuid = generateUUID(
            _rewards,
            block.timestamp,
            allStakers.length
        );

        AllStake storage stake = stakesUid[uuid];

        stake.amount = 0; 
        // totalStaked += amountWithDecimals; 
        // stake.lastUpdated = block.timestamp;
        stake.accuRewards = 0;
        stake.totalStakedInPool = totalStaked;
        stake.currentRewardRate = updateRewardPerToken();
        stake.add = msg.sender;
        stake.hasUnstaked = false;
        stake.isPostExpiry = false; 
        stake.uuid = uuid;
        // stake.stakeUuid = 0;
        stake.createdAt = block.timestamp;

        allStakers.push(stake);
        stakesUid[uuid] = stake;
        count();


}

    //util - calculate emission rate
    function currTokRet() internal view returns (uint256) {
        if (poolEndTime > block.timestamp) {
            return totalPoolRewards / (poolEndTime - block.timestamp);
        } else {
            return 0;
        }
    }

    //util - count number of stakers
    function count() internal returns (uint256) {
        // stakeLength = stakers.length;
        allStakeLength = allStakers.length;
        return allStakeLength;
    }

    //util - generate uuid
    function generateUUID(
        uint256 _amount,
        uint256 _stakeTime,
        uint256 _index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_amount, _stakeTime, _index));
    }

    // util - update reward per token
    function updateRewardPerToken() internal returns (uint256) {
        rewardPerToken = totalStaked > 0
            ? (rewardRatePerSecond * precisionFactor) / totalStaked
            : 0; //zero since no staking is there

        // console.log("rewardPerToken!", rewardPerToken);
        return rewardPerToken;
    }

    //STAKE USER TOKENS
    function stakeTokens(uint256 _amount) external nonReentrant {
        require(
            block.timestamp < poolEndTime - lockinDuration,
            "Staking period has ended"
        );
        require(_amount > 0, "Must stake a postive amount!!");
        require(totalRewardsLeft > 0, "No rewards left to distribute");

        bytes32 uuid = generateUUID(
            _amount,
            block.timestamp,
            allStakers.length
        );

        //receive staking tokens,
        require(
            stakingToken.transferFrom(
                msg.sender,
                address(this),
                // amountWithDecimals
                _amount
            ),
            "Token Transfer failed"
        );
        //mutiply to calculate with precisions
        uint256 amountWithDecimals = _amount * tokenDecimalFactor;
        //maintain staker data
        AllStake storage allStaker = stakesUid[uuid];

        allStaker.amount = amountWithDecimals; // Set the user's stake amount
        totalStaked += amountWithDecimals; // Update the total staked amount
        // allStaker.stakeTime = block.timestamp; // Set stake time
        allStaker.lastUpdated = block.timestamp; // Update the last updated time for this staker
        allStaker.accuRewards = 0;
        // allStaker.totalStakedInPool = (totalStaked * precisionFactor * deci); //skipping for now
        allStaker.totalStakedInPool = totalStaked;
        allStaker.currentRewardRate = updateRewardPerToken();
        allStaker.add = msg.sender;
        allStaker.hasUnstaked = false;
        // allStaker.isUnstake = false;
        allStaker.isPostExpiry= false; 
        allStaker.uuid = uuid;
        allStaker.stakeUuid = 0;
        allStaker.createdAt = block.timestamp;
        allStakers.push(allStaker);

        stakesUid[uuid] = allStaker;
        count();
    }

    //UNSTAKE TOKENS
    function unstakeTokens(bytes32 stakinguuid) external nonReentrant {
        AllStake storage userStake = stakesUid[stakinguuid];
        //check if good actor
        require(userStake.add == msg.sender, "you can only unstake your stakings!!");
        //check if already staked
        require(userStake.hasUnstaked != true, "already unstaked!");
        require(userStake.amount > 0, "No tokens to unstake");
        require(
            block.timestamp >= userStake.createdAt + lockinDuration,
            "Tokens are still locked"
        );
        // Calculate the accumulated rewards till now
        uint256 accumulatedRewards = this.calculateRewards(stakinguuid);
        //update accuRewards
        console.log("accumulatedRewards",accumulatedRewards);
        userStake.accuRewards += accumulatedRewards;
        userStake.hasUnstaked = true;
        userStake.unstakeTime = block.timestamp;
        userStake.lastUpdated = block.timestamp;
        //update total stake
        totalStaked -= (userStake.amount); //keep same 
        //update total rewards left
        // totalRewardsLeft -= accumulatedRewards;
        totalRewardsLeft -= accumulatedRewards * precisionFactor;
        console.log("new total stake",totalStaked);
        uint256 totalAmt = accumulatedRewards + (userStake.amount/tokenDecimalFactor);
        require(
            stakingToken.transfer(msg.sender, totalAmt),
            "Token transfer failed"
        );
        //add unstake entry
        bytes32 uuid = generateUUID(
            userStake.amount,
            block.timestamp,
            allStakers.length
        );

        AllStake storage allStaker = stakesUid[uuid];

        allStaker.amount = 0; // set amount to 0
        // allStaker.stakeTime = 0; // Set stake time 0
        allStaker.lastUpdated = block.timestamp; // Update the last updated time for this staker
        allStaker.accuRewards = 0;
        allStaker.totalStakedInPool = totalStaked;
        //set new reward rate
        allStaker.currentRewardRate = updateRewardPerToken();
        allStaker.add = msg.sender;
        allStaker.hasUnstaked = true;
        // allStaker.isUnstake = true;
        allStaker.isPostExpiry = block.timestamp > poolEndTime ? true : false;
        allStaker.uuid = uuid;
        allStaker.stakeUuid = stakinguuid;
        allStaker.createdAt = block.timestamp;
        allStakers.push(allStaker);

        stakesUid[uuid] = allStaker;
        count();
    }

    //CLAIM REWARDS
    function claimTokens(bytes32 stakinguuid) external nonReentrant {
        AllStake storage userStake = stakesUid[stakinguuid];
        require(userStake.add == msg.sender, "you can only unstake your stakings!!");
        //check if already staked
        require(userStake.hasUnstaked != true, "already unstaked!!");
        uint256 accumulatedRewards = this.calculateRewards(stakinguuid);
        userStake.accuRewards += accumulatedRewards;
        userStake.lastUpdated = block.timestamp;
        //update total rewards left
        totalRewardsLeft -= accumulatedRewards * precisionFactor;
        require(
            stakingToken.transfer(msg.sender, accumulatedRewards),
            "Token transfer failed"
        );
    }


    //util - calculate rewards
    function calculateRewards(bytes32 stakinguuid)
        external
        view
        returns (
            uint256
        )
    {
        AllStake storage userStake = stakesUid[stakinguuid];

        if(userStake.hasUnstaked==true){ //logically holds no tokens as rewards
            return 0;
        }

        bool isPostExpiry = block.timestamp > poolEndTime ? true : false;

        console.log("Stake Amount", userStake.amount);
        console.log("isPostExpiry", isPostExpiry);

        uint256 accumulatedRewards = 0;

        uint256 stakeslen = allStakers.length; //length of all stake and unstake'
        for (uint256 i = stakeslen; i > 0; i--) {
            AllStake storage currStaker = allStakers[i -1];
            
            if (currStaker.isPostExpiry) {
                continue;
            }

            uint256 stakeDuration = 0;
            uint256 blockRewardRate = currStaker.currentRewardRate;

            // if (currStaker.isPostExpiry == false ) {
                if (i == stakeslen && isPostExpiry == false) {
                    
                    stakeDuration = block.timestamp -  currStaker.createdAt;
                    // blockRewardRate = currStaker.currentRewardRate;
                } else if(isPostExpiry) {
                    stakeDuration = poolEndTime -  currStaker.createdAt;
                    isPostExpiry = false;

                } else {
                    stakeDuration = allStakers[i].createdAt - currStaker.createdAt;
                    // blockRewardRate = currStaker.currentRewardRate;
                }
                
                console.log(i, "blockRewardRate", blockRewardRate);
                console.log(i, "stakeDuration", stakeDuration);

                accumulatedRewards +=
                    ((((stakeDuration * blockRewardRate * userStake.amount) /
                        precisionFactor) / tokenDecimalFactor))/deci;

                console.log("accumulatedRewards", accumulatedRewards);
            // }

            if (userStake.uuid == currStaker.uuid) {
                break;
            }
        }
        // uint256 currRew = accumulatedRewards - userStake.accuRewards;
        uint256 currRew = accumulatedRewards > userStake.accuRewards 
                     ? accumulatedRewards - userStake.accuRewards 
                     : 0;
        return currRew;
    }    
    

    function getAllStakings(address userAddress)
        external
        view
        returns (AllStake[] memory)
    {
        uint256 userStakeCount = 0;
        // First pass: count the number of stakes for the user
        for (uint256 i = 0; i < allStakers.length; i++) {
            if (allStakers[i].add == userAddress) {
                userStakeCount++;
            }
        }

        // Allocate memory for the user stakes array
        AllStake[] memory userStakes = new AllStake[](userStakeCount);
        uint256 index = 0;

        // Second pass: populate the user stakes array from stakesUid mapping
        for (uint256 i = 0; i < allStakers.length; i++) {
            if (allStakers[i].add == userAddress) {
                bytes32 uuid = allStakers[i].uuid;
                userStakes[index] = stakesUid[uuid];
                index++;
            }
        }
        return userStakes;
    }

    //discuss if need this
    modifier onlyOwner() {
        require(msg.sender == poolCreator, "Permission denied");
         _;
    }
    
    //incase of emergency, withdraw funds!
    function withdraw(uint256 amount) external onlyOwner {
        require(msg.sender == poolCreator, "only admin can withdraw!");
        stakingToken.transfer(poolCreator, amount);
    }

    //set staking pool details
   function getPoolDetails() external view returns (
        address _poolCreator,
        uint256 _poolEndTime, 
        uint256 _lockinDuration,
        uint256 _totalStaked, 
        uint256 _rewardRatePerSecond,
        uint256 _totalPoolRewards,
        uint256 _totalRewardsLeft,
        uint256 _rewardPerToken,
        uint256 _tokenDecimalFactor,
        uint256 _deci,
        uint256 _createdAt,
        uint256 _updatedAt
    ) {
        return (
            poolCreator,
            poolEndTime, 
            lockinDuration,
            totalStaked, 
            rewardRatePerSecond,
            totalPoolRewards,
            totalRewardsLeft,
            rewardPerToken,
            tokenDecimalFactor,
            deci,
            createdAt,
            updatedAt
        );
    }

    // View function to get all staker addresses
    function getStakerAddresses() public view returns (address[] memory) {
        // Step 1: Use an auxiliary array to keep track of unique addresses
        address[] memory tempArray = new address[](allStakers.length);
        uint256 uniqueCount = 0;

        // Step 2: Use nested loops to check for uniqueness
        for (uint256 i = 0; i < allStakers.length; i++) {
            address stakerAddress = allStakers[i].add;
            bool isUnique = true;

            for (uint256 j = 0; j < uniqueCount; j++) {
                if (tempArray[j] == stakerAddress) {
                    isUnique = false;
                    break;
                }
            }

            if (isUnique) {
                tempArray[uniqueCount] = stakerAddress;
                uniqueCount++;
            }
        }

        // Step 3: Create the final array of unique addresses
        address[] memory uniqueAddresses = new address[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueAddresses[i] = tempArray[i];
        }

        return uniqueAddresses;
    }
}