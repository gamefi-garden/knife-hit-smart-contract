// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library KnifeHitLogic {
    //10 Level
    struct KnifeHitGameConfig {
        uint16 knifeMoveTime;

        uint16 colliderOffset;

        KnifeHitLevelConfig[10] configs;
    }

    struct KnifeHitLevelConfig {
        uint16 oneRotationTime;
        uint32[] obstacle;
    }
    //configs 
    // { knifeMoveTime = 300; colliderOffset = 100}
    //configs 
    // {oneRotationTime 5000, obstacle {0;1000;2000;4000} }
    // {oneRotationTime 3000, obstacle {0;1000;2000} }
    function CalculateScore(uint32[][10] memory action, KnifeHitGameConfig memory gameConfig) internal pure returns (uint32 s)
    {
        uint32 score = 0;
        uint32 obstacleIdx = 0;
        int32 actionValidIdx = -1;
        uint32 lastActionValidIdx = 0;

        for (uint32 level = 0; level < action.length; level++) {

            KnifeHitLevelConfig memory levelconfig = gameConfig.configs[level];
            uint32[] memory actionValid = new uint32[](action[level].length);

            for(uint32 i = 0; i < action[level].length;i++ )
            {
                uint32 triggerTime = (action[level][i] + gameConfig.knifeMoveTime) % levelconfig.oneRotationTime;

                if (action[level][i] >= levelconfig.oneRotationTime)
                {
                    obstacleIdx = 0;
                    actionValidIdx = 0;
                }

                uint obstacleTime = levelconfig.obstacle[obstacleIdx] + gameConfig.colliderOffset;
           
                while (triggerTime > obstacleTime)
                {
                    obstacleIdx++;
                    obstacleTime = levelconfig.obstacle[obstacleIdx] + gameConfig.colliderOffset;
                        
                }
                if (triggerTime >= levelconfig.obstacle[obstacleIdx])
                {
                    // Debug.LogError("==================Collider Obstacle=============");
                    continue;
                }
        
                while (actionValidIdx != -1 
                    && uint32(actionValidIdx) < actionValid.length -1
                    && triggerTime > actionValid[uint32(actionValidIdx)] + gameConfig.colliderOffset)
                {
                    actionValidIdx++;
                }

          
            if (actionValidIdx != -1 &&
             triggerTime <= actionValid[uint32(actionValidIdx)] + gameConfig.colliderOffset)
            {
                // Debug.LogError("==================Collider Action=============");
                break;
            }

            if (actionValidIdx == -1)
            {
                actionValidIdx = 0;
            }
            
            score++;
                
            actionValid[lastActionValidIdx] = triggerTime;
            lastActionValidIdx++;

            }

         
        }
        return score;
    }


    // 0 1000-> 1trigfger     -> 5000

    function compare(
        uint32[][10] memory _player1Actions,
        uint32[][10] memory _player2Actions,
        KnifeHitGameConfig memory configs
    ) internal pure returns (uint32) {
        uint32 result = CalculateScore(_player1Actions,configs) - CalculateScore(_player2Actions,configs);
        return result;
    }

}
