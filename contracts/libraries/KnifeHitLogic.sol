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
    
    //Todo
    function CalculateScore(uint32[][10] memory action, KnifeHitGameConfig memory configs) internal pure returns (uint32 s)
    {
        uint32 score = 0;
        // uint32 idxObstacle;
        // for (uint32 i = 0; i < action.length; i++) {
        //     KnifeHitLevelConfig config = configs[i];

        //     bool valid = (action[i] + knifeMoveTime);
        // }
        return score;

    }

    function compare(
        uint32[][10] memory _player1Actions,
        uint32[][10] memory _player2Actions,
        KnifeHitGameConfig memory configs
    ) internal pure returns (uint32) {
        uint32 result = CalculateScore(_player1Actions,configs) - CalculateScore(_player2Actions,configs);
        return result;
    }

}
