// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library KnifeHitLogic {
    //10 Level
    struct KnifeHitGameConfig {
        uint32 knifeMoveTime;
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
 
    function CalculateScore(uint32[10][] memory action,KnifeHitGameConfig memory gameConfig) internal pure returns (uint32 s)
    {

        uint _score = 0;

        uint32 posOfKnife;

        for (uint level = 0; level < action.length; level++) 
        {

            KnifeHitLevelConfig memory levelConfig = gameConfig.configs[level];
            uint totalKnife = levelConfig.obstacle;
            uint32 timePerSection = levelConfig.rotateSpeed / gameConfig.ratio;

            for (uint i = 0; i < action[level].length; i++)
            {
                uint32 triggerTime = (action[level][i] + gameConfig.knifeMoveTime) % levelConfig.rotateSpeed;

                posOfKnife = triggerTime / timePerSection;

                uint bitmask = 1 << posOfKnife;
                bool hasValue = (totalKnife & bitmask) != 0;

                if (hasValue) {

                    // return _score;
                    break;
                }
                _score++;
                totalKnife |= bitmask;
            }
        }

        return uint32(_score);
    }

    function compare(
        uint32[10][] memory _player1Actions,
        uint32[10][] memory _player2Actions,
        KnifeHitGameConfig memory configs
    ) internal pure returns (uint32) {
        uint32 result = CalculateScore(_player1Actions,configs) - CalculateScore(_player2Actions,configs);
        return result;
    }

}
