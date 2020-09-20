//
//  GameContext.swift
//  0003_GameArchTest
//
//  Created by Kikutada on 2020/08/12.
//  Copyright © 2020 Kikutada. All rights reserved.
//

import Foundation

/// Context and settings for game
class CgContext {

    enum EnLanguage: Int {
        case English = 0, Japanese
    }

    var language: EnLanguage = .Japanese

    var highScore = 100
    var score = 0
    var numberOfPlayers = 0
    var round = 1
    var credit = 1

    var score_extendPlayer: Int = 0
    var score_extendedPlayer: Bool = false
    
    var elapsedTime: Int = 0
    
    var numberOfFeeds: Int = 0
    var playerMiss: Bool = false
    var numberOfFeedsEatedByMiss: Int = 0
    var numberOfFeedsEated: Int = 0
    var numberOfFeedsRemaingToSpurt: Int = 0
    var numberOfFeedsToAppearSpecialTarget: Int = 0
    var kindOfSpecialTarget: CgSpecialTarget.EnSpecialTarget = .None
    
    var ghostPts: CgScorePts.EnScorePts = .pts100

    func resetGame() {
        score = 0
        numberOfPlayers = 3
        round = 1
        score_extendPlayer = (language == .English) ? 20000 : 10000
        score_extendedPlayer = false
    }
        
    func resetRound() {
        playerMiss = false
        numberOfFeedsEatedByMiss = 0
        numberOfFeedsEated = 0
        numberOfFeedsToAppearSpecialTarget = 70
        numberOfFeedsRemaingToSpurt = 20
        resetSpecialTarget()
        resetGhostPts()
    }
    
    func setPlayerMiss() {
        numberOfFeedsEatedByMiss = 0
        playerMiss = true
    }

    func resetSpecialTarget() {
        let roundTable: [CgSpecialTarget.EnSpecialTarget] = [.Cherry, .Strawberry, .Orange, .Orange, .Apple, .Apple, .Melon, .Melon, .Galaxian, .Galaxian, .Key]
        let kind = round >= roundTable.count ? roundTable.count-1 : round-1
        kindOfSpecialTarget = roundTable[kind]
    }
    
    func resetGhostPts() {
        ghostPts = .pts200
    }
    
    /// Update high score
    /// - Returns: If true, the high score has been updated.
    func updateHighScore()->Bool {
        let highScoreUpdated: Bool = score > highScore
        if highScoreUpdated { highScore = score }
        return highScoreUpdated
    }
    
    /// Update timing to appear special target
    func updateSpecialTargetAppeared() {
        numberOfFeedsToAppearSpecialTarget += 100
    }
    
    func getNumberOfGhostsForAppearace() -> Int {
        let numberOfGhosts: Int
        // Miss Bypass Sequence
        if playerMiss {
            // Level A
            if numberOfFeedsEatedByMiss < 7 {
                numberOfGhosts = 1
            } else if numberOfFeedsEatedByMiss < 17 {
                numberOfGhosts = 2
            } else if numberOfFeedsEatedByMiss < 32 {
                numberOfGhosts = 3
            } else {
                playerMiss = false
                numberOfGhosts = getNumberOfGhostsForAppearace()
            }
        } else {
            // Level A
            if numberOfFeedsEated < 30 {
                numberOfGhosts = 2
            } else if numberOfFeedsEated < 90 {
                numberOfGhosts = 3
            } else {
                numberOfGhosts = 4
            }
        }
        return numberOfGhosts
    }
    
    func judgeGhostsWavyChase(time: Int) -> Bool {
        let mode: Bool
        // Level A
        if time < 7000 || (time >= 27000 && time < 34000) ||
           (time >= 54000 && time < 59000) || (time >= 79000 && time < 84000) {
            mode = false
        } else {
            mode = true
        }
        return mode
    }
    
    func judgeBlinkySpurt() -> Bool {
        let feedsRemain: Int = numberOfFeeds - numberOfFeedsEated
        return (feedsRemain <= numberOfFeedsRemaingToSpurt)
    }

}
