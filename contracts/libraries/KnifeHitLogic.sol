// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "hardhat/console.sol";

library KnifeHitLogic {
    //10 Level
    struct KnifeHitGameConfig {
        uint32 gameDuration;
        uint32 ratio;
        KnifeHitLevelConfig[10] configs;
    }

    struct KnifeHitLevelConfig {
        uint easeType; 
        uint32 rotateSpeed; // time 1 vong quay
        uint32 knifeCount;
        uint32 obstacle; // obstacle bit mask | 1: khong the cam dao vao 
    }
     error InvalidAction(); 

    function CalculateScore(uint32[] memory action,KnifeHitGameConfig memory gameConfig) internal pure returns (uint32 s)
    {
        uint _score = 0;

        uint32 posOfKnife;

        for (uint level = 0; level < action.length; level++) 
        {
            KnifeHitLevelConfig memory levelConfig = gameConfig.configs[level];
            uint totalKnife = levelConfig.obstacle;
            uint32 timePerSection = levelConfig.rotateSpeed / gameConfig.ratio;


            uint32[] memory actions = new uint32[](32); // Assuming uint is 32 bits
            uint32 actionsCount = 0;

            for (uint32 i = 0; i < 32; i++) {
                uint bitmask = 1 << i;
                if ((action[level] & bitmask) != 0) {
                    actions[actionsCount] = i * timePerSection; // Assuming actions are evenly spaced
                    actionsCount++;
                }
            }


            uint32[] memory trimmedActions = new uint32[](actionsCount);
            for (uint j = 0; j < actionsCount; j++) {
                trimmedActions[j] = actions[j];
                console.log("Action Time: ");

                console.log(trimmedActions[j]);
            }
            console.log("Cacule Score");


            // uint32[] memory trimmedActions = revertActionData(action[level],gameConfig,level);
            for (uint i = 0; i < trimmedActions.length; i++)
            {
                uint32 triggerTime = (trimmedActions[i]) % levelConfig.rotateSpeed;

                posOfKnife = triggerTime / timePerSection;

                uint bitmask = 1 << posOfKnife;
                bool hasValue = (totalKnife & bitmask) != 0;
                console.log("posOfKnife");
                console.log(posOfKnife);
                console.log("bitmask");

                console.log(bitmask);
                console.log("totalKnife");
                console.log(totalKnife);

                if (hasValue) {
                    console.log("InvalidAction");

                    revert InvalidAction();
                }
                _score++;
                console.log(_score);

                totalKnife |= bitmask;
                console.log("totalKnifeV2 :");
                console.log(totalKnife);
                console.log("==========");

            }
        }

        return uint32(_score);
    }

    function revertActionData(uint actionData,KnifeHitGameConfig memory gameConfig, uint idx) public  returns (uint32[] memory) {
        uint32 timePerSection = gameConfig.configs[idx].rotateSpeed / gameConfig.ratio;

        uint32[] memory actions = new uint32[](32); // Assuming uint is 32 bits
        uint32 actionsCount = 0;

        for (uint32 i = 0; i < 32; i++) {
            uint bitmask = 1 << i;
            if ((actionData & bitmask) != 0) {
                actions[actionsCount] = i * timePerSection; // Assuming actions are evenly spaced
                actionsCount++;
            }
        }

        uint32[] memory trimmedActions = new uint32[](actionsCount);
        for (uint j = 0; j < actionsCount; j++) {
            trimmedActions[j] = actions[j];
        }

        return trimmedActions;
    }

    function compare(
        uint32[] memory _player1Actions,
        uint32[] memory _player2Actions,
        KnifeHitGameConfig memory configs
    ) internal pure returns (uint32) {
        uint32 result = CalculateScore(_player1Actions,configs) - CalculateScore(_player2Actions,configs);
        return result;
    }

}
