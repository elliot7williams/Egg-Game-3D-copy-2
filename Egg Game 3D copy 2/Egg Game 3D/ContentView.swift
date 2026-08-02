//
//  ContentView.swift
//  Egg Game 3D
//
//  Created by Elliot Williams on 2025-06-22.
//

import SwiftUI
import SceneKit
import CoreMotion
import AVFoundation

// MARK: - Game Models
struct PowerUp: Identifiable {
    let id = UUID()
    let type: PowerUpType
    let position: SCNVector3
    let duration: TimeInterval
    
    enum PowerUpType: String, CaseIterable {
        case scoreMultiplier = "Score Multiplier"
        case slowMotion = "Slow Motion"
        case magneticBasket = "Magnetic Basket"
        case doublePoints = "Double Points"
        case shieldProtection = "Shield Protection"
        case rainbowEggs = "Rainbow Eggs"
        
        var color: UIColor {
            switch self {
            case .scoreMultiplier: return .orange
            case .slowMotion: return .cyan
            case .magneticBasket: return .purple
            case .doublePoints: return .yellow
            case .shieldProtection: return .blue
            case .rainbowEggs: return .magenta
            }
        }
    }
}

struct GameStats {
    var totalEggsCaught: Int = 0
    var totalPlayTime: TimeInterval = 0
    var longestStreak: Int = 0
    var currentStreak: Int = 0
    var powerUpsCollected: Int = 0
    var specialEggsCaught: Int = 0
    var level: Int = 1
    var experience: Int = 0
    
    var experienceToNextLevel: Int {
        return level * 100
    }
}

enum EggType: String, CaseIterable {
    case normal = "Normal"
    case golden = "Golden"
    case diamond = "Diamond"
    case bomb = "Bomb"
    case rainbow = "Rainbow"
    case ice = "Ice"
    case fire = "Fire"
    
    var points: Int {
        switch self {
        case .normal: return 1
        case .golden: return 5
        case .diamond: return 10
        case .bomb: return -5
        case .rainbow: return 15
        case .ice: return 2
        case .fire: return 3
        }
    }
    
    var color: UIColor {
        switch self {
        case .normal: return .white
        case .golden: return .systemYellow
        case .diamond: return .cyan
        case .bomb: return .red
        case .rainbow: return .systemPink
        case .ice: return .systemBlue
        case .fire: return .systemOrange
        }
    }
    
    var rarity: Double {
        switch self {
        case .normal: return 0.7
        case .golden: return 0.15
        case .diamond: return 0.05
        case .bomb: return 0.08
        case .rainbow: return 0.01
        case .ice: return 0.08
        case .fire: return 0.08
        }
    }
}

struct EggCatcherGame: View {
    @State private var score = 0
    @State private var eggsMissed = 0
    @State private var gameActive = true
    @State private var gameStartTime: Date?
    @State private var highScore = UserDefaults.standard.integer(forKey: "highScore")
    @State private var achievements: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "achievements") ?? [])
    @State private var showAchievement = false
    @State private var latestAchievement = ""
    @State private var gameStats = GameStats()
    @State private var activePowerUps: [PowerUp] = []
    @State private var showStats = false
    @State private var currentStreak = 0
    @State private var comboMultiplier = 1.0
    @State private var lastCatchTime: TimeInterval?
    @State private var specialEffectsActive = false
    @State private var shieldActive = false
    @State private var magneticBasketActive = false
    @State private var doublePointsActive = false
    @State private var slowMotionActive = false
    
    var body: some View {
        ZStack {
            // Game Scene
            GameSceneView(score: $score, eggsMissed: $eggsMissed, gameActive: $gameActive)
                .edgesIgnoringSafeArea(.all)
            
            // Game UI
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Score: \(score) (Best: \(highScore))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                        
                        Text("Missed: \(eggsMissed)/10")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(eggsMissed < 8 ? .yellow : .red)
                            .shadow(color: .black, radius: 2)
                        
                        // Streak indicator
                        if currentStreak > 1 {
                            Text("Streak: \(currentStreak)x")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.orange)
                                .shadow(color: .black, radius: 2)
                        }
                        
                        // Level and XP
                        HStack {
                            Text("Lv.\(gameStats.level)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.cyan)
                            
                            ProgressView(value: Double(gameStats.experience), total: Double(gameStats.experienceToNextLevel))
                                .frame(width: 60)
                                .tint(.cyan)
                        }
                    }
                    
                    Spacer()
                    
                    VStack {
                        Button(action: {
                            showStats.toggle()
                        }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 10)
                        
                        Button(action: {
                            gameActive.toggle()
                        }) {
                            Image(systemName: gameActive ? "pause.circle" : "play.circle")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                // Active power-ups display
                if !activePowerUps.isEmpty {
                    HStack {
                        ForEach(activePowerUps) { powerUp in
                            VStack {
                                Circle()
                                    .fill(Color(powerUp.type.color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: iconFor(powerUp.type))
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    )
                                Text(powerUp.type.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                if !gameActive {
                    Text("PAUSED")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 5)
                }
                
                if eggsMissed >= 10 {
                    VStack {
                        Text("GAME OVER")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.red)
                            .shadow(color: .black, radius: 5)
                        
                        Text("Final Score: \(score)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 10)
                        
                        Button(action: {
                            // Update high score if needed
                            if score > highScore {
                                highScore = score
                                UserDefaults.standard.set(highScore, forKey: "highScore")
                            }
                            score = 0
                            eggsMissed = 0
                            gameActive = true
                        }) {
                            Text("Play Again")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                }
                
                Spacer()
                
Text("Tilt device to move basket")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
            }
            
            // Achievement Notification
            if showAchievement {
                VStack {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text("Achievement Unlocked!")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(latestAchievement)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    Spacer()
                }
                .transition(.move(edge: .top))
                .animation(.easeInOut(duration: 0.5), value: showAchievement)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showAchievement = false
                    }
                }
            }
            
            // Stats overlay
            if showStats {
                VStack {
                    HStack {
                        Text("Game Statistics")
                            .font(.title2)
                            .foregroundColor(.white)
                        Spacer()
                        Button("Close") {
                            showStats = false
                        }
                        .foregroundColor(.white)
                    }
                    .padding()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Level: \(gameStats.level)")
                            .foregroundColor(.white)
                        Text("Experience: \(gameStats.experience)/\(gameStats.experienceToNextLevel)")
                            .foregroundColor(.white)
                        Text("Total Eggs Caught: \(gameStats.totalEggsCaught)")
                            .foregroundColor(.white)
                        Text("Longest Streak: \(gameStats.longestStreak)")
                            .foregroundColor(.white)
                        Text("Power-Ups Collected: \(gameStats.powerUpsCollected)")
                            .foregroundColor(.white)
                        Text("Special Eggs: \(gameStats.specialEggsCaught)")
                            .foregroundColor(.white)
                    }
                    .padding()
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.9))
                .cornerRadius(20)
                .padding()
            }
        }
        .background(Color.black)
    }
    
    func activatePowerUp(_ powerUp: PowerUp) {
        switch powerUp.type {
        case .scoreMultiplier:
            score += 10
        case .slowMotion:
            slowMotionActive = true
        case .magneticBasket:
            magneticBasketActive = true
        case .doublePoints:
            doublePointsActive = true
        case .shieldProtection:
            shieldActive = true
        case .rainbowEggs:
            specialEffectsActive = true
        }
        
        activePowerUps.append(powerUp)
        gameStats.powerUpsCollected += 1
        
        // Remove power-up after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + powerUp.duration) {
            deactivatePowerUp(powerUp)
        }
        
        playSoundEffect(name: "power_up")
    }
    
    func deactivatePowerUp(_ powerUp: PowerUp) {
        switch powerUp.type {
        case .slowMotion:
            slowMotionActive = false
        case .magneticBasket:
            magneticBasketActive = false
        case .doublePoints:
            doublePointsActive = false
        case .shieldProtection:
            shieldActive = false
        case .rainbowEggs:
            specialEffectsActive = false
        default:
            break
        }
        
        activePowerUps.removeAll { $0.id == powerUp.id }
    }
    
    func iconFor(_ powerUpType: PowerUp.PowerUpType) -> String {
        switch powerUpType {
        case .scoreMultiplier:
            return "multiply"
        case .slowMotion:
            return "tortoise"
        case .magneticBasket:
            return "magnet"
        case .doublePoints:
            return "2.circle"
        case .shieldProtection:
            return "shield"
        case .rainbowEggs:
            return "rainbow"
        }
    }
    
    func updateStats() {
        gameStats.totalEggsCaught += 1
        gameStats.experience += 10
        
        if gameStats.experience >= gameStats.experienceToNextLevel {
            gameStats.level += 1
            gameStats.experience = 0
            showLevelUp()
        }
        
        if currentStreak > gameStats.longestStreak {
            gameStats.longestStreak = currentStreak
        }
    }
    
    func showLevelUp() {
        latestAchievement = "Level Up! Now level \(gameStats.level)"
        showAchievement = true
    }
    
    func checkAchievements() {
        if score >= 50 && !achievements.contains("Score50") {
            achievements.insert("Score50")
            showAchievementNotification("Score Master: Reached 50 points!")
        }
        
        if currentStreak >= 10 && !achievements.contains("Streak10") {
            achievements.insert("Streak10")
            showAchievementNotification("Streak Master: 10 consecutive catches!")
        }
        
        if gameStats.specialEggsCaught >= 5 && !achievements.contains("SpecialEggs5") {
            achievements.insert("SpecialEggs5")
            showAchievementNotification("Special Collector: 5 special eggs caught!")
        }
        
        UserDefaults.standard.set(Array(achievements), forKey: "achievements")
    }
    
    func showAchievementNotification(_ message: String) {
        latestAchievement = message
        showAchievement = true
    }
    
    func resetGame() {
        score = 0
        eggsMissed = 0
        currentStreak = 0
        comboMultiplier = 1.0
        activePowerUps.removeAll()
        gameActive = true
        gameStartTime = Date()
        
        // Reset power-up states
        shieldActive = false
        magneticBasketActive = false
        doublePointsActive = false
        slowMotionActive = false
        specialEffectsActive = false
    }
}


struct GameSceneView: UIViewRepresentable {
    @Binding var score: Int
    @Binding var eggsMissed: Int
    @Binding var gameActive: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = createGameScene()
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = false
        scnView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0)
        scnView.delegate = context.coordinator
        scnView.isPlaying = true
        
        // Add swipe gesture for camera control
        let swipeGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipe(_:)))
        scnView.addGestureRecognizer(swipeGesture)
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        context.coordinator.setGameActive(gameActive)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, score: $score, eggsMissed: $eggsMissed, gameActive: $gameActive)
    }
    
    func createGameScene() -> SCNScene {
        let scene = SCNScene()
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
cameraNode.position = SCNVector3(0, 7, 15)
        scene.rootNode.addChildNode(cameraNode)
        
        // Lighting
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor(white: 0.3, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLightNode)
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
directionalLight.intensity = 1500
        directionalLight.castsShadow = true
        directionalLight.shadowRadius = 5
        directionalLight.shadowColor = UIColor.black.withAlphaComponent(0.5)
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(0, 10, 0)
        directionalLightNode.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(directionalLightNode)
        
        // Ground
        let groundGeometry = SCNFloor()
        groundGeometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.5)
        groundGeometry.firstMaterial?.specular.contents = UIColor.white
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.position = SCNVector3(0, -1, 0)
        scene.rootNode.addChildNode(groundNode)
        
// Skybox with fallback
let skyImages = ["sky_cloud_1.png", "sky_cloud_2.png", "sky_cloud_3.png", "sky_cloud_4.png", "sky_cloud_5.png", "sky_cloud_6.png"].compactMap { UIImage(named: $0) }
        if !skyImages.isEmpty {
            scene.background.contents = skyImages
        } else {
            // Fallback to gradient background
            scene.background.contents = UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        }
        
        // Basket
        let basket = createBasket()
        basket.position = SCNVector3(0, 0.5, 0)
        scene.rootNode.addChildNode(basket)
        
        // Trees
        for i in -1...1 {
            for j in -1...1 {
                if i != 0 || j != 0 {
                    let tree = createTree()
                    tree.position = SCNVector3(Float(i) * 8, 0, Float(j) * 8)
                    scene.rootNode.addChildNode(tree)
                }
            }
        }
        
        // Rabbits
        for _ in 0..<3 {
            let rabbit = createRabbit()
            rabbit.position = SCNVector3(
                Float.random(in: -5...5),
                0,
                Float.random(in: -5...5)
            )
            scene.rootNode.addChildNode(rabbit)
        }
        
        return scene
    }
    
    func createBasket() -> SCNNode {
        let basketNode = SCNNode()
        
        // Basket base
        let basketBase = SCNCylinder(radius: 1, height: 0.2)
        basketBase.firstMaterial?.diffuse.contents = UIColor.brown
        let baseNode = SCNNode(geometry: basketBase)
        baseNode.position.y = 0.1
        basketNode.addChildNode(baseNode)
        
        // Basket sides
        for i in 0..<8 {
            let angle = Float(i) * (Float.pi / 4)
            let stick = SCNBox(width: 0.1, height: 1, length: 0.1, chamferRadius: 0.05)
            stick.firstMaterial?.diffuse.contents = UIColor.brown
            let stickNode = SCNNode(geometry: stick)
            stickNode.position = SCNVector3(sin(angle), 0.5, cos(angle))
            basketNode.addChildNode(stickNode)
        }
        
        // Basket handle
        let handle = SCNTorus(ringRadius: 0.8, pipeRadius: 0.05)
        handle.firstMaterial?.diffuse.contents = UIColor.brown
        let handleNode = SCNNode(geometry: handle)
        handleNode.position.y = 1
        handleNode.eulerAngles.x = Float.pi / 2
        basketNode.addChildNode(handleNode)
        
        // Physics body
        let sphere = SCNSphere(radius: 1.0)
        let physicsShape = SCNPhysicsShape(geometry: sphere, options: nil)
        let physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
        basketNode.physicsBody = physicsBody
        basketNode.name = "basket"
        
        return basketNode
    }
    
    func createTree() -> SCNNode {
        let treeNode = SCNNode()
        
        // Trunk
        let trunk = SCNCylinder(radius: 0.3, height: 2)
        trunk.firstMaterial?.diffuse.contents = UIColor.brown
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position.y = 1
        treeNode.addChildNode(trunkNode)
        
        // Leaves
        let leaves = SCNSphere(radius: 1.2)
        leaves.firstMaterial?.diffuse.contents = UIColor.green
        let leavesNode = SCNNode(geometry: leaves)
        leavesNode.position.y = 3
        treeNode.addChildNode(leavesNode)
        
        return treeNode
    }
    
    func createRabbit() -> SCNNode {
        let rabbitNode = SCNNode()
        
        // Body
        let body = SCNCylinder(radius: 0.3, height: 0.5)
        body.firstMaterial?.diffuse.contents = UIColor.white
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = 0.25
        rabbitNode.addChildNode(bodyNode)
        
        // Head
        let head = SCNSphere(radius: 0.25)
        head.firstMaterial?.diffuse.contents = UIColor.white
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0.25, 0.4)
        rabbitNode.addChildNode(headNode)
        
        // Ears
        for i in [-1, 1] {
            let ear = SCNCylinder(radius: 0.05, height: 0.6)
            ear.firstMaterial?.diffuse.contents = UIColor.systemPink
            let earNode = SCNNode(geometry: ear)
            earNode.position = SCNVector3(Float(i) * 0.15, 0.5, 0)
            earNode.eulerAngles.z = Float(i) * 0.2
            rabbitNode.addChildNode(earNode)
        }
        
        // Eyes
        for i in [-1, 1] {
            let eye = SCNSphere(radius: 0.05)
            eye.firstMaterial?.diffuse.contents = UIColor.black
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.position = SCNVector3(Float(i) * 0.1, 0.25, 0.55)
            rabbitNode.addChildNode(eyeNode)
        }
        
        // Physics body
        let physicsShape = SCNPhysicsShape(geometry: SCNSphere(radius: 0.4), options: nil)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        physicsBody.isAffectedByGravity = false
        physicsBody.categoryBitMask = 4
        physicsBody.collisionBitMask = 0
        rabbitNode.physicsBody = physicsBody
        rabbitNode.name = "rabbit"
        
        return rabbitNode
    }
    
var lastCatchTime: TimeInterval? // Initializing last catch time

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: GameSceneView
        var score: Binding<Int>
        var eggsMissed: Binding<Int>
        var gameActive: Binding<Bool>
        var lastUpdateTime: TimeInterval?
        var basketNode: SCNNode?
        var motionManager: CMMotionManager?
        var cameraAngle: Float = 0
        
        init(parent: GameSceneView, score: Binding<Int>, eggsMissed: Binding<Int>, gameActive: Binding<Bool>) {
            self.parent = parent
            self.score = score
            self.eggsMissed = eggsMissed
            self.gameActive = gameActive
            super.init()
            setupMotionManager()
        }
        
        func setGameActive(_ active: Bool) {
            // Update the binding's wrapped value
            gameActive.wrappedValue = active
        }
        
        func setupMotionManager() {
            motionManager = CMMotionManager()
            if motionManager?.isDeviceMotionAvailable == true {
                motionManager?.deviceMotionUpdateInterval = 1/60
                motionManager?.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                    guard let self = self, let motion = motion else { return }
                    
                    let rotationRateX = Float(motion.rotationRate.x) * 0.1
                    let rotationRateZ = Float(motion.rotationRate.z) * 0.1
                    
                    if self.gameActive.wrappedValue {
                        self.basketNode?.position.x -= rotationRateZ
                        self.basketNode?.position.z -= rotationRateX
                        
                        self.basketNode?.position.x = max(-8, min(8, self.basketNode?.position.x ?? 0))
                        self.basketNode?.position.z = max(-8, min(8, self.basketNode?.position.z ?? 0))
                    }
                }
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let scene = renderer.scene else { return }
            
            if basketNode == nil {
                basketNode = scene.rootNode.childNode(withName: "basket", recursively: true)
            }
            
            let deltaTime: TimeInterval
            if let lastUpdateTime = lastUpdateTime {
                deltaTime = time - lastUpdateTime
            } else {
                deltaTime = 0
            }
            lastUpdateTime = time
            
            guard gameActive.wrappedValue, eggsMissed.wrappedValue < 10 else { return }
            
            let dropRate = max(5, 10 - score.wrappedValue / 10)
            if Int.random(in: 0...100) < dropRate {
                spawnEgg(in: scene)
            }
            
            // Spawn power-ups occasionally
            if Int.random(in: 0...500) < 2 {
                spawnPowerUp(in: scene)
            }
            
            for node in scene.rootNode.childNodes {
                if node.name?.hasPrefix("egg_") == true {
                    node.eulerAngles.x += Float(deltaTime) * 2
                    node.eulerAngles.z += Float(deltaTime) * 1.5
                    
                    if node.position.y < 0 {
                        node.removeFromParentNode()
                        eggsMissed.wrappedValue += 1
                        if eggsMissed.wrappedValue >= 10 {
                            playSoundEffect(name: "game_over")
                        }
                    }
                }
                
                if node.name == "rabbit" {
                    node.position.x += Float.random(in: -0.01...0.01)
                    node.position.z += Float.random(in: -0.01...0.01)
                    
                    node.position.x = max(-8, min(8, node.position.x))
                    node.position.z = max(-8, min(8, node.position.z))
                    
                    node.eulerAngles.y += Float(deltaTime) * 0.5
                }
            }
            
            if let camera = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                let basketPos = basketNode?.position ?? SCNVector3(0, 0.5, 0)
                camera.position = SCNVector3(
                    basketPos.x + 8 * sin(cameraAngle),
                    5,
                    basketPos.z + 8 * cos(cameraAngle)
                )
                camera.look(at: basketPos)
            }
        }
        
        func spawnEgg(in scene: SCNScene) {
            let eggType = randomEggType()
            let eggGeometry = SCNSphere(radius: 0.2)
            eggGeometry.firstMaterial?.diffuse.contents = eggType.color
            
            // Add special effects based on egg type
            switch eggType {
            case .golden:
                eggGeometry.firstMaterial?.emission.contents = UIColor.yellow.withAlphaComponent(0.3)
                eggGeometry.firstMaterial?.shininess = 1.0
            case .diamond:
                eggGeometry.firstMaterial?.specular.contents = UIColor.white
                eggGeometry.firstMaterial?.shininess = 2.0
            case .bomb:
                eggGeometry.firstMaterial?.emission.contents = UIColor.red.withAlphaComponent(0.5)
            case .rainbow:
                eggGeometry.firstMaterial?.emission.contents = UIColor.systemPink.withAlphaComponent(0.6)
            default:
                eggGeometry.firstMaterial?.shininess = 0.5
            }
            
            let eggNode = SCNNode(geometry: eggGeometry)
            eggNode.position = SCNVector3(
                Float.random(in: -8...8),
                15,
                Float.random(in: -8...8)
            )
            eggNode.name = "egg_\(eggType.rawValue)"
            
            let physicsShape = SCNPhysicsShape(geometry: SCNSphere(radius: 0.2), options: nil)
            let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
            physicsBody.isAffectedByGravity = true
            physicsBody.categoryBitMask = 1
            physicsBody.contactTestBitMask = 2
            eggNode.physicsBody = physicsBody
            
            scene.rootNode.addChildNode(eggNode)
        }
        
        func randomEggType() -> EggType {
            let random = Double.random(in: 0...1)
            var cumulativeWeight = 0.0
            
            for eggType in EggType.allCases {
                cumulativeWeight += eggType.rarity
                if random <= cumulativeWeight {
                    return eggType
                }
            }
            
            return .normal
        }
        
        func spawnPowerUp(in scene: SCNScene) {
            let powerUpType = PowerUp.PowerUpType.allCases.randomElement()!
            let powerUpGeometry = SCNBox(width: 0.3, height: 0.3, length: 0.3, chamferRadius: 0.1)
            powerUpGeometry.firstMaterial?.diffuse.contents = powerUpType.color
            powerUpGeometry.firstMaterial?.emission.contents = powerUpType.color.withAlphaComponent(0.5)
            
            let powerUpNode = SCNNode(geometry: powerUpGeometry)
            powerUpNode.position = SCNVector3(
                Float.random(in: -8...8),
                15,
                Float.random(in: -8...8)
            )
            powerUpNode.name = "powerUp_\(powerUpType.rawValue)"
            
            // Add rotation animation
            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2)
            let repeatRotation = SCNAction.repeatForever(rotation)
            powerUpNode.runAction(repeatRotation)
            
            let physicsShape = SCNPhysicsShape(geometry: powerUpGeometry, options: nil)
            let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
            physicsBody.isAffectedByGravity = true
            physicsBody.categoryBitMask = 3
            physicsBody.contactTestBitMask = 2
            powerUpNode.physicsBody = physicsBody
            
            scene.rootNode.addChildNode(powerUpNode)
        }
        
        @objc func handleSwipe(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .changed else { return }
            
            let translation = gesture.translation(in: gesture.view)
            cameraAngle += Float(translation.x) * 0.01
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
            guard let scene = renderer.scene else { return }
            scene.physicsWorld.contactDelegate = self
        }
    }
}

extension GameSceneView.Coordinator: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        // Handle egg catches
        if (contact.nodeA.name?.hasPrefix("egg_") == true && contact.nodeB.name == "basket") ||
           (contact.nodeA.name == "basket" && contact.nodeB.name?.hasPrefix("egg_") == true) {
            
            let eggNode = contact.nodeA.name?.hasPrefix("egg_") == true ? contact.nodeA : contact.nodeB
            
            // Get egg type from name
            if let nodeName = eggNode.name,
               let eggTypeString = nodeName.components(separatedBy: "_").last,
               let eggType = EggType(rawValue: eggTypeString) {
                
                // Handle different egg types
                switch eggType {
                case .bomb:
                    if score.wrappedValue >= 5 {
                        score.wrappedValue -= 5
                    }
                    playSoundEffect(name: "bomb")
                case .normal:
                    score.wrappedValue += 1
                    playSoundEffect(name: "collect")
                case .golden:
                    score.wrappedValue += 5
                    playSoundEffect(name: "golden")
                case .diamond:
                    score.wrappedValue += 10
                    playSoundEffect(name: "diamond")
                case .rainbow:
                    score.wrappedValue += 15
                    playSoundEffect(name: "rainbow")
                case .ice:
                    score.wrappedValue += 2
                    playSoundEffect(name: "ice")
                case .fire:
                    score.wrappedValue += 3
                    playSoundEffect(name: "fire")
                }
                
                // Track special eggs
                if eggType != EggType.normal {
                    // This would need to be communicated back to the parent view
                    // For now, just play special sound
                    if eggType != EggType.bomb {
                        playSoundEffect(name: "special")
                    }
                }
            }
            
            eggNode.removeFromParentNode()
            
            // Score multiplier for consecutive catches
            let currentTime = CACurrentMediaTime()
            if let lastCatch = parent.lastCatchTime, currentTime - lastCatch < 2.0 {
                score.wrappedValue += 2 // Bonus points for quick consecutive catches
            }
            parent.lastCatchTime = currentTime
        }
        
        // Handle power-up collection
        if (contact.nodeA.name?.hasPrefix("powerUp_") == true && contact.nodeB.name == "basket") ||
           (contact.nodeA.name == "basket" && contact.nodeB.name?.hasPrefix("powerUp_") == true) {
            
            let powerUpNode = contact.nodeA.name?.hasPrefix("powerUp_") == true ? contact.nodeA : contact.nodeB
            
            // Get power-up type from name
            if let nodeName = powerUpNode.name {
                let powerUpTypeString = nodeName.components(separatedBy: "_").dropFirst().joined(separator: " ")
                if let powerUpType = PowerUp.PowerUpType(rawValue: powerUpTypeString) {
                
                // Create power-up and activate it
                let powerUp = PowerUp(
                    type: powerUpType,
                    position: powerUpNode.position,
                    duration: 10.0 // 10 seconds duration
                )
                
                // This would need to be communicated back to the parent view
                // For now, just play sound and add score
                score.wrappedValue += 5
                playSoundEffect(name: "power_up")
                }
            }
            
            powerUpNode.removeFromParentNode()
        }
    }
}

func playSoundEffect(name: String) {
    guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }

    var soundEffect: AVAudioPlayer?
    do {
        soundEffect = try AVAudioPlayer(contentsOf: url)
        soundEffect?.play()
    } catch {
        print("Failed to play sound: \(error)")
    }

}

struct ContentView: View {
    var body: some View {
        EggCatcherGame()
    }
}
