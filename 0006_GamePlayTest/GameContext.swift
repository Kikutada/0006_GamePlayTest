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
    
    var numberOfFeeds: Int = 0
    var numberOfFeedsEatedByMiss: Int = 0
    var numberOfFeedsEated: Int = 0
    var numberOfFeedsToAppearSpecialTarget: Int = 0
    var kindOfSpecialTarget: CgSpecialTarget.EnSpecialTarget = .None
    
    var ghostPts: CgScorePts.EnScorePts = .pts100

    func resetGame() {
        score = 0
        numberOfPlayers = 6
        round = 1
        score_extendPlayer = (language == .English) ? 20000 : 10000
        score_extendedPlayer = false
    }
        
    func resetRound() {
//        numberOfFeeds = 0
        numberOfFeedsEatedByMiss = 0
        numberOfFeedsEated = 0
        numberOfFeedsToAppearSpecialTarget = 70
        kindOfSpecialTarget = .Cherry
        resetGhostPts()
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
}
