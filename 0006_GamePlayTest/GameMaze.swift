//
//  GameMaze.swift
//  0003_GameArchTest
//
//  Created by Kikutada on 2020/08/13.
//  Copyright © 2020 Kikutada. All rights reserved.
//

import Foundation

let MAZE_MAX_DISTANCE: Int  = 36*36+44*44
let MAZE_UNIT: Int = 8
let HALF_MAZE_UNIT: Int = MAZE_UNIT/2

/// Kind of tile int the maze
enum EnMazeTile: Int {
    case Road = 0x00
    case Feed = 0x01
    case PowerFeed = 0x02
    case Fruit = 0x03
    case Slow = 0xFC
    case Oneway = 0xFD
    case Gate = 0xFE
    case Wall = 0xFF
    
    init?( _ value : Int) {
        switch value {
            case 0x00: self = .Road
            case 0x01: self = .Feed
            case 0x02: self = .PowerFeed
            case 0x03: self = .Fruit
            case 0xFC: self = .Slow
            case 0xFD: self = .Oneway
            case 0xFE: self = .Gate
            case 0xFF: self = .Wall
            default:   return nil
        }
    }

    func getTexture() -> Int {
        switch self {
            case .Road: return 464 // blank
            case .Feed: return 593
            case .PowerFeed: return 595
            case .Fruit: return 0
            case .Slow: return 464 // blank
            case .Oneway: return 464 // blank
            case .Gate: return 0
            case .Wall: return 0
        }
    }
}

/// Protocol  for actors
protocol ActorDeligate {
    func isSuspendUpdating() -> Bool
    func playerEatFeed(column: Int, row: Int, power: Bool)
    func playerEatFruit(column: Int, row: Int)
    func getPlayerSpeed(action: CgPlayer.EnPlayerAction, with power: Bool) -> Int
    func getTimeOfPlayerWithPower() -> Int
    func getTimeOfPlayerNotToEat() -> Int
    func getGhostSpeed(action: CgGhost.EnGhostAction) -> Int
    func setTile(column: Int, row: Int, value: EnMazeTile)
    func getTile(column: Int, row: Int) -> EnMazeTile
    func getTileAttribute(to direction: EnDirection, position: CgPosition) -> EnMazeTile
}

/// Maze scene class for play mode
/// This class has some methods to draw a maze and starting messages.
class CgSceneMaze: CgSceneFrame, ActorDeligate {

    enum EnGameModelSequence: Int {
        case Init = 0
        case Start, Ready, Go, Updating, ReturnToUpdating, RoundClear, PrepareFlashMaze, FlashMaze,
             PlayerMissed, PlayerDisappeared, PlayerRestart, GameOver
    }

    var player: CgPlayer!
    var blinky: CgGhostBlinky!
    var pinky: CgGhostPinky!
    var inky: CgGhostInky!
    var clyde: CgGhostClyde!
    var ptsManager: CgScorePtsManager!
    var specialTarget: CgSpecialTarget!
    var ghosts = CgGhostManager()

    convenience init(object: CgSceneFrame) {
        self.init(binding: object, context: object.context, sprite: object.sprite, background: object.background, sound: object.sound)
        player = CgPlayer(binding: self, deligateActor: self)
        blinky = CgGhostBlinky(binding: self, deligateActor: self)
        pinky  = CgGhostPinky(binding: self, deligateActor: self)
        inky   = CgGhostInky(binding: self, deligateActor: self)
        clyde  = CgGhostClyde(binding: self, deligateActor: self)
        ptsManager = CgScorePtsManager(binding: self, deligateActor: self)
        specialTarget = CgSpecialTarget(binding: self, deligateActor: self)
        
        ghosts.append(blinky)
        ghosts.append(pinky)
        ghosts.append(inky)
        ghosts.append(clyde)
    }

    /// Handle sequence
    /// To override in a derived class.
    /// - Parameter sequence: Sequence number
    /// - Returns: If true, continue the sequence, if not, end the sequence.
    override func handleSequence(sequence: Int) -> Bool {
        guard let sequenceLabel: EnGameModelSequence = EnGameModelSequence(rawValue: sequence) else { return false }

        switch sequenceLabel {
            case .Init: sequenceInit()
            case .Start: sequenceStart()
            case .Ready: sequenceReady()
            case .Go: sequenceGo()
            case .Updating: sequenceUpdating()
            case .ReturnToUpdating: sequenceReturnToUpdating()
            case .RoundClear: sequenceRoundClear()
            case .PrepareFlashMaze: sequencePrepareFlashMaze()
            case .FlashMaze: sequenceFlashMaze()
            case .PlayerMissed: sequencePlayerMissed()
            case .PlayerDisappeared: seauencePlayerDisappeared()
            case .PlayerRestart: sequencePlayerRestart()

            default:
                // Stop and exit running sequence.
                return false
        }
        
        // Continue running sequence.
        return true
    }

    // ============================================================
    //  Do activities in state.
    // ============================================================
    func sequenceInit() {
        drawBackground()
        goToNextSequence()
    }
    
    func sequenceStart() {
        context.resetGame()
        context.resetRound()
        context.numberOfFeeds = drawMazeWithSettingValuesAndAttributes()
        printBlinking1Up()
        printPlayers(appearance: false)
        printStateMessage(.PlayerOneReady)
        sound.enableOutput(true)
        sound.playSE(.Beginning)
        goToNextSequence(.Ready, after: 2240)
    }
    
    func sequenceReady() {
        printStateMessage(.ClearPlayerOne)
        printPlayers(appearance: true)
        player.reset()
        ghosts.reset()
        specialTarget.reset()
        ptsManager.reset()
        goToNextSequence(.Go, after: 1880)
    }
    
    func sequenceGo() {
        printStateMessage(.ClearReady)
        drawPowerFeed(state: .Blinking)
        player.start()
        ghosts.start()
        goToNextSequence()
    }
    
    func sequenceUpdating() {
        // Player checks to collide ghost.
        let collisionresult = ghosts.detectCollision(playerPosition: player.position)

        switch collisionresult {
            case .None:
                // Set the chase state after after the time that the player doesn't eat feed.
                if player.timer_playerNotToEat.isEventFired()  {
                    blinky.chase(playerPosition: player.position)
                    pinky.chase(playerPosition: player.position, playerDirection: player.direction.get())
                    inky.chase(playerPosition: player.position, blinkyPosition: blinky.position)
                    clyde.chase(playerPosition: player.position)
                    ghosts.setStateToGoOut()

                } else {
                    ghosts.setStateToScatter()
                }
                
                // If Blinky becomes spurt or not.
                if isGhostSpurt() {
                    blinky.state.setSpurt(true)
                    blinky.chase(playerPosition: player.position)
                } else {
                    blinky.state.setSpurt(false)
                }

                // For debug
                ghosts.drawTargetPosition(show: true)

            case .GhostEated:
                let pts = context.ghostPts
                ptsManager.start(kind: pts, position: ghosts.collisionPosition, interval: 62*16)  // 1000ms
                context.ghostPts = pts.get2times()
                addScore(pts: pts.getScore())
                player.stop()
                player.clear()
                specialTarget.enabled = false
                ghosts.stopWithoutEscaping()
                sound.playSE(.EatGhost)
                sound.stopBGM()  // REMARKS: To change playBGM(.BgmEscaping) immediately.
                goToNextSequence(.ReturnToUpdating, after: 1000)

            case .PlayerMiss:
                goToNextSequence(.PlayerMissed)
        }
        
        playBGM()
    }

    func sequenceReturnToUpdating() {
        player.start()
        ghosts.startWithoutEscaping()
        specialTarget.enabled = true
        goToNextSequence(.Updating)
    }
    
    func sequenceRoundClear() {
        sound.stopBGM()
        player.stop()
        player.clear()
        player.draw(to: .None)
        ghosts.stop()
        ghosts.draw()
        goToNextSequence(.PrepareFlashMaze, after: 1914)
    }
    
    func sequencePrepareFlashMaze() {
        ghosts.clear()
        ghosts.drawTargetPosition(show: false)
        specialTarget.stop()
        ptsManager.stop()
        blinkingTimer = 104  // 104*16ms = 1664ms
        goToNextSequence()
    }

    func sequenceFlashMaze() {
        if blinkingTimer > 0 {
            let remain = blinkingTimer % 26
            if remain == 0 {
                drawMazeWall(color: .White)
            } else if remain == 13 { // 13*16ms = 208ms
                drawMazeWall(color: .Blue)
            }
            blinkingTimer -= 1
        } else {
            context.round += 1
            context.resetRound()
            context.numberOfFeeds = drawMazeWithSettingValuesAndAttributes()
            printBlinking1Up()
            printStateMessage(.Ready)
            goToNextSequence(.Ready)
        }
    }
    
    func sequencePlayerMissed() {
        player.stop()
        player.draw(to: .Stop)
        ghosts.stop()
        sound.stopBGM()
        goToNextSequence(.PlayerDisappeared, after: 990)
    }

    func seauencePlayerDisappeared() {
        player.drawPlayerDisappeared()
        ghosts.clear()
        ghosts.drawTargetPosition(show: false)
        sound.playSE(.Miss)
        goToNextSequence(.PlayerRestart, after: 2700)
    }

    func sequencePlayerRestart() {
        specialTarget.stop()
        ptsManager.stop()
        context.numberOfPlayers -= 1

        if context.numberOfPlayers > 0 {
            printStateMessage(.Ready)
            drawPowerFeed(state: .Stop)
            goToNextSequence(.Ready)
        } else {
            printStateMessage(.GameOver)
            drawPowerFeed(state: .Clear)
            goToNextSequence(.GameOver)
        }
    }

    // ============================================================
    //  Implement for protocol to ActorDeligate
    // ============================================================

    func playerEatFeed(column: Int, row: Int, power: Bool) {
        background.put(0, column: column, row: row, texture: EnMazeTile.Road.getTexture())
        setTile(column: column,row: row, value: .Road)

        if power {
            context.resetGhostPts()
            ghosts.setStateToFrightened(time: getTimeOfPlayerWithPower())
            addScore(pts: 50)
        } else {
            sound.playSE(.EatDot)
            addScore(pts: 10)
        }
        
        // Count eated feeds
        context.numberOfFeedsEated += 1

        // Judgment of appearance of special target
        if context.numberOfFeedsEated == context.numberOfFeedsToAppearSpecialTarget {
            specialTarget.setKind(to: context.kindOfSpecialTarget)
            specialTarget.start()
            context.updateSpecialTargetAppeared()
        }
        
        if  context.numberOfFeedsEated == context.numberOfFeeds {
            goToNextSequence(.RoundClear)
        }

    }

    func getTimeOfPlayerWithPower() -> Int {
        return 6000 //ms
    }
    
    func getTimeOfPlayerNotToEat() -> Int {
        return 7000 // ms
    }
    
    func playerEatFruit(column: Int, row: Int) {
        background.put(0, column: column, row: row, texture: EnMazeTile.Road.getTexture())
        setTile(column: column,row: row, value: .Road)

        sound.playSE(.EatFruit)
        specialTarget.stop()

        let kind = specialTarget.getKind().getScorePts()
        ptsManager.start(kind: kind, position: specialTarget.position, interval: 2000)  // 2000ms
        addScore(pts: kind.getScore())
    }
    
    func getPlayerSpeed(action: CgPlayer.EnPlayerAction, with power: Bool) -> Int {
        let speed: Int
        switch action {
            case .Walking where !power : speed = 16
            case .Walking where  power : speed = 18
            case .EatingFeed where !power : speed = 15
            case .EatingFeed where  power : speed = 17
            case .EatingPower where !power : speed = 13
            case .EatingPower where  power : speed = 15
            case .EatingFruit where !power : speed = 15
            case .EatingFruit where  power : speed = 17
            default: speed = 16
        }
        return speed
    }

    func getGhostSpeed(action: CgGhost.EnGhostAction) -> Int {
        let speed: Int
        switch action {
            case .Walking: speed = 15
            case .Spurting: speed =  16
            case .Frightened: speed = 10
            case .Warping: speed = 8
            case .GoingOut: fallthrough
            case .Standby: speed = 8
            case .Escaping: speed = 32
            case .None: speed = 16
        }
        return speed
    }

    func setTile(column: Int, row: Int, value: EnMazeTile) {
        mazeValues[column][row] = value
    }

    func getTile(column: Int, row: Int) -> EnMazeTile {
        if column < 0 {
            return mazeValues[BG_WIDTH-1][row]
        } else if column >= BG_WIDTH {
            return mazeValues[0][row]
        }
        return mazeValues[column][row]
    }

    func getTileAttribute(to direction: EnDirection, position: CgPosition) -> EnMazeTile {
        let column = position.column
        let row = position.row
        switch direction {
            case .Left where position.dx <= 0 : return getTileAttribute(column: column-1, row: row)
            case .Left where position.dx > 0 : return getTileAttribute(column: column, row: row)
            case .Right where position.dx < 0 : return getTileAttribute(column: column, row: row)
            case .Right where position.dx >= 0 : return getTileAttribute(column: column+1, row: row)
            case .Up where position.dy < 0 : return getTileAttribute(column: column, row: row)
            case .Up where position.dy >= 0 : return getTileAttribute(column: column, row: row+1)
            case .Down where position.dy <= 0 : return getTileAttribute(column: column, row: row-1)
            case .Down where position.dy > 0 : return getTileAttribute(column: column, row: row)
            default    : return getTileAttribute(column: column  , row: row)
        }
    }

    private func getTileAttribute(column: Int, row: Int) -> EnMazeTile {
        if column < 0 {
            return mazeAttributes[BG_WIDTH-1][row]
        } else if column >= BG_WIDTH {
            return mazeAttributes[0][row]
        }
        return mazeAttributes[column][row]
    }

    // ============================================================
    //  General methods in this class
    // ============================================================

    func goToNextSequence(_ number: EnGameModelSequence, after time: Int = 0) {
        goToNextSequence(number.rawValue, after: time)
    }

    func playBGM() {
        if ghosts.isEscapeState() {
            sound.playBGM(.BgmEscaping)
        } else if ghosts.isFrightenedState() {
            sound.playBGM(.BgmPower)
        } else {
            let numberOfRemainingFeeds = context.numberOfFeeds - context.numberOfFeedsEated
            if numberOfRemainingFeeds <= 16 {
                sound.playBGM(.BgmSpurt4)
            } else if numberOfRemainingFeeds <= 32 {
                sound.playBGM(.BgmSpurt3)
            } else if numberOfRemainingFeeds <= 64 {
                sound.playBGM(.BgmSpurt2)
            } else if numberOfRemainingFeeds <= 128 {
                sound.playBGM(.BgmSpurt1)
            } else {
                sound.playBGM(.BgmNormal)
            }
        }
    }

    func isGhostSpurt() -> Bool {
        let feedsRemain: Int = context.numberOfFeeds - context.numberOfFeedsEated
        return (feedsRemain <= context.numberOfFeedsRemaingToSpurt) && !ghosts.isGhostInNest()
    }

    func isSuspendUpdating() -> Bool {
        return getNextSequence() == EnGameModelSequence.ReturnToUpdating.rawValue
    }
    

    func addScore(pts: Int) {
        context.score += pts
        printPlayerScore()
        if context.updateHighScore() {
            printHighScore()
        }
        if !context.score_extendedPlayer {
            if context.score >= context.score_extendPlayer {
                context.score_extendedPlayer = true
                sound.playSE(.ExtraPacman)
                context.numberOfPlayers += 1
                printPlayers()
            }
        }
    }

    
    struct StMazePosition {
        var column: Int
        var row: Int
    }

    private var mazeValues = [[EnMazeTile]](repeating: [EnMazeTile](repeating: .Road, count: BG_HEIGHT), count: BG_WIDTH)
    private var mazeAttributes = [[EnMazeTile]](repeating: [EnMazeTile](repeating: .Road, count: BG_HEIGHT), count: BG_WIDTH)
    private var powerFeeds = [StMazePosition]()
    private var blinkingTimer: Int = 0

    func drawMazeWithSettingValuesAndAttributes() -> Int {
        let numberOfFeeds = setMazeValuesAndAttributes()
        drawMaze()
        printFrame()
        printPlayerScore()
        printHighScore()
        printRounds()

        return numberOfFeeds
    }
    
    private func setMazeValuesAndAttributes() -> Int {
        
        let mazeSource = getMazeSource()
        var row = BG_HEIGHT-4
        var numberOfFeeds = 0
        powerFeeds.removeAll()

        for str in mazeSource {
            var column = 0
            for c in str {
                switch(c) {
                    case "_" :
                        mazeValues[column][row] = EnMazeTile.Road
                        mazeAttributes[column][row] = EnMazeTile.Slow
                    case " " :
                        mazeValues[column][row] = EnMazeTile.Road
                        mazeAttributes[column][row] = EnMazeTile.Road
                    case "1" :
                        mazeValues[column][row] = EnMazeTile.Feed
                        mazeAttributes[column][row] = EnMazeTile.Road
                        numberOfFeeds += 1
                    case "2" :
                        mazeValues[column][row] = EnMazeTile.Feed
                        mazeAttributes[column][row] = EnMazeTile.Oneway
                        numberOfFeeds += 1
                    case "3" :
                        mazeValues[column][row] = EnMazeTile.PowerFeed
                        mazeAttributes[column][row] = EnMazeTile.Road
                        numberOfFeeds += 1
                        let pd = StMazePosition(column: column, row: row)
                        powerFeeds.append(pd)
                    default :
                        mazeValues[column][row] = EnMazeTile.Wall
                        mazeAttributes[column][row] = EnMazeTile.Wall
                }
                column += 1
            }
            row -= 1
        }
        
        return numberOfFeeds
    }

    ///　Draw maze with walls and dots
    private func drawMaze() {
        var row = BG_HEIGHT-4
        
        let mazeSource = getMazeSource()

        for str in mazeSource {
            var i = 0
            for c in str.utf8 {
                let txNo: Int
                switch c {
                    case 50 : txNo = 592  // Oneway with dot "2" -> "1"
                    case 95 : txNo = 576  // Slow "_" -> " "
                    default : txNo = Int(c)+544 // 576-32
                }
                background.put(0, column: i, row: row, texture: txNo)
                i += 1
            }
            row -= 1
        }
    }
    
    /// Maze color
    enum EnMazeWallColor: Int {
        case Blue = 0, White = 1
    }
    
    /// Draw only the wall of the maze
    /// - Parameter color: Maze color
    private func drawMazeWall(color: EnMazeWallColor) {
        var row = BG_HEIGHT-4
        let offset: Int = color.rawValue*48

        let mazeSource = getMazeSource()

        for str in mazeSource {
            var i = 0
            for c in str.utf8 {
                let txNo: Int
                if c < 57 || c == 87 {
                    txNo = offset+576
                } else {
                    txNo = Int(c)+offset+544
                }
                background.put(0, column: i, row: row, texture: txNo)
                i += 1
            }
            row -= 1
        }
    }

    enum EnPowerFeedState {
        case Clear, Stop, Blinking
        
        func getTexture()->Int {
            switch self {
                case .Clear: return 464
                case .Stop: return 595
                case .Blinking: return 768
            }
        }
    }

    func drawPowerFeed(state: EnPowerFeedState) {
        for t in powerFeeds {
            if mazeValues[t.column][t.row] == EnMazeTile.PowerFeed {
                background.put(0, column: t.column, row: t.row, texture: state.getTexture())
            }
        }
    }

    func printBlinking1Up() {
        background.put(0, column: 3, row: 35, texture: 769)  // 1 -> 1
        background.put(0, column: 4, row: 35, texture: 770)  // 2 -> U
        background.put(0, column: 5, row: 35, texture: 771)  // 3 -> P
    }

    enum EnPrintStateMessage {
        case PlayerOneReady, Ready, ClearPlayerOne, ClearReady, GameOver
    }
    
    /// Print starting message
    /// - Parameter state: Kind of message
    func printStateMessage(_ state: EnPrintStateMessage) {
        switch state {
            case .PlayerOneReady:
                background.print(0, color: .Cyan, column:  9, row: 21, string: "PLAYER ONE")
                fallthrough
            case .Ready:
                background.print(0, color: .Yellow, column: 11, row: 15, string: "READY!")
            case .ClearPlayerOne:
                background.print(0, color: .Cyan, column:  9, row: 21, string: "          ")
            case .ClearReady:
                background.print(0, color: .Yellow, column: 11, row: 15, string: "      ")
            case .GameOver:
                background.print(0, color: .Red, column:  9, row: 15, string: "GAME  OVER")
        }
    }


    func getMazeSource() -> [String] {
        
        let mazeSource: [String] = [
            "aggggggggggggjiggggggggggggb",
            "e111111111111EF111111111111f",
            "e1AGGB1AGGGB1EF1AGGGB1AGGB1f",
            "e3E  F1E   F1EF1E   F1E  F3f",
            "e1CHHD1CHHHD1CD1CHHHD1CHHD1f",
            "e11111111111111111111111111f",
            "e1AGGB1AB1AGGGGGGB1AB1AGGB1f",
            "e1CHHD1EF1CHHJIHHD1EF1CHHD1f",
            "e111111EF1111EF1111EF111111f",
            "chhhhB1EKGGB1EF1AGGLF1Ahhhhd",
            "     e1EIHHD2CD2CHHJF1f     ",
            "     e1EF          EF1f     ",
            "     e1EF QhUWWVhR EF1f     ",
            "gggggD1CD f      e CD1Cggggg",
            "____  1   f      e   1  ____" ,
            "hhhhhB1AB f      e AB1Ahhhhh",
            "     e1EF SggggggT EF1f     ",
            "     e1EF          EF1f     ",
            "     e1EF AGGGGGGB EF1f     ",
            "aggggD1CD1CHHJIHHD1CD1Cggggb",
            "e111111111111EF111111111111f",
            "e1AGGB1AGGGB1EF1AGGGB1AGGB1f",
            "e1CHJF1CHHHD2CD2CHHHD1EIHD1f",
            "e311EF1111111  1111111EF113f",
            "kGB1EF1AB1AGGGGGGB1AB1EF1AGl",
            "YHD1CD1EF1CHHJIHHD1EF1CD1CHZ",
            "e111111EF1111EF1111EF111111f",
            "e1AGGGGLKGGB1EF1AGGLKGGGGB1f",
            "e1CHHHHHHHHD1CD1CHHHHHHHHD1f",
            "e11111111111111111111111111f",
            "chhhhhhhhhhhhhhhhhhhhhhhhhhd"
        ]

        return mazeSource
    }

}
