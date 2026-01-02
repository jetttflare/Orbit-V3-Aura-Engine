import SwiftUI
import SceneKit

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#elseif os(iOS)
import UIKit
typealias PlatformColor = UIColor
#endif

// MARK: - "Star Citizen" Grade Solar System

enum PlanetType: String, CaseIterable {
    case mercury = "GROK"        // AI/Logic
    case venus = "EMPIRE"        // Business/Assets
    case earth = "CYBER"         // Security/Defense
    case mars = "SYSTEMS"        // Devices/Infrastructure
    case jupiter = "DATA"        // Analytics
    case saturn = "VOICE"        // Comms
    case uranus = "CREATIVE"     // UI/Gen
    case neptune = "TIME"        // History
    
    // Aesthetic Properties
    var baseColor: PlatformColor {
        switch self {
        case .mercury: return PlatformColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1.0) // Dark Tech
        case .venus: return PlatformColor(red: 0.8, green: 0.5, blue: 0.0, alpha: 1.0) // Dense Atmosphere
        case .earth: return PlatformColor(red: 0.0, green: 0.2, blue: 0.5, alpha: 1.0) // Deep Ocean
        case .mars: return PlatformColor(red: 0.6, green: 0.2, blue: 0.1, alpha: 1.0) // Rusty
        case .jupiter: return PlatformColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 1.0) // Banded Gas
        case .saturn: return PlatformColor(red: 0.8, green: 0.7, blue: 0.4, alpha: 1.0) // Pale Gold
        case .uranus: return PlatformColor(red: 0.4, green: 0.6, blue: 0.6, alpha: 1.0) // Ice Giant
        case .neptune: return PlatformColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1.0) // Deep Blue
        }
    }
    
    var atmosphereColor: PlatformColor {
        switch self {
        case .mercury: return PlatformColor(red: 0.5, green: 0.0, blue: 1.0, alpha: 1.0)
        case .venus: return PlatformColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0)
        case .earth: return PlatformColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        case .mars: return PlatformColor(red: 0.8, green: 0.4, blue: 0.3, alpha: 1.0)
        case .jupiter: return PlatformColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1.0)
        case .saturn: return PlatformColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1.0)
        case .uranus: return PlatformColor(red: 0.6, green: 0.9, blue: 0.9, alpha: 1.0)
        case .neptune: return PlatformColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
        }
    }
    
    var radius: CGFloat {
        switch self {
        case .mercury: return 1.5
        case .venus: return 2.8
        case .earth: return 3.0
        case .mars: return 2.0
        case .jupiter: return 8.0
        case .saturn: return 7.0
        case .uranus: return 4.5
        case .neptune: return 4.2
        }
    }
    
    var distance: Float {
        switch self {
        case .mercury: return 25.0
        case .venus: return 40.0
        case .earth: return 55.0
        case .mars: return 75.0
        case .jupiter: return 110.0
        case .saturn: return 150.0
        case .uranus: return 190.0
        case .neptune: return 230.0
        }
    }
    
    var speed: Double {
        switch self {
        case .mercury: return 6.0
        case .venus: return 4.0
        case .earth: return 3.5
        case .mars: return 2.5
        case .jupiter: return 1.2
        case .saturn: return 0.9
        case .uranus: return 0.6
        case .neptune: return 0.4
        }
    }
}

struct OrbView: View {
    @StateObject private var viewModel = SolarSystemViewModel()
    @EnvironmentObject var backendService: BackendService
    
    var body: some View {
        ZStack {
            SceneView(
                scene: viewModel.scene,
                options: [.allowsCameraControl, .autoenablesDefaultLighting, .rendersContinuously]
            )
            .ignoresSafeArea()
            .onAppear { viewModel.start() }
            .onChange(of: backendService.orbState) { newState in
                viewModel.updateSunState(newState)
            }
        }
    }
}

class SolarSystemViewModel: ObservableObject {
    let scene = SCNScene()
    private var sunNode: SCNNode!
    private var planetNodes: [PlanetType: SCNNode] = [:]
    
    // Shader for Atmospheric Scattering (The "Rim Glow" effect)
    private let atmosphereShaderModifier = """
    #pragma transparent
    #pragma body
    
    // Calculate Fresnel effect based on view angle
    float3 viewDir = normalize(_surface.view.cameraPosition - _surface.position);
    float fresnel = pow(1.0 - dot(_surface.normal, viewDir), 2.5); // Sharp rim
    
    // Add glowing rim
    float3 atmosphere = _surface.diffuse.rgb * fresnel * 3.0;
    _surface.emission += float4(atmosphere, 1.0);
    
    // Fade center to make it look like a shell
    _surface.diffuse.a = fresnel * 0.8 + 0.1;
    """
    
    // Shader for Dynamic Sun Interior
    private let sunShaderModifier = """
    #pragma body
    float3 p = _surface.position;
    float time = u_time * 0.2;
    // Simple pseudo-noise based on sine waves for plasma ripple
    float noise = sin(p.x*0.5 + time) * sin(p.y*0.5 - time) * sin(p.z*0.5 + time);
    
    _surface.emission.rgb += float3(noise * 0.2, noise * 0.1, 0.0);
    """
    
    func start() {
        setupScene()
        setupStarfield() // Massive scale
        setupSun()       // Blindingly bright
        setupPlanets()   // PBR + Atmosphere
        setupOrbits()    // Subtle guidelines
    }
    
    private func setupScene() {
        scene.background.contents = PlatformColor.black
        
        // 1. Camera - Cinematic visual settings
        let camera = SCNCamera()
        camera.fieldOfView = 50 // Telephoto compression
        camera.zFar = 2000
        camera.wantsHDR = true
        camera.exposureOffset = -1.0 // Crusher blacks, brighter lights
        camera.averageGray = 0.2
        camera.bloomIntensity = 1.8 // Strong glow
        camera.bloomThreshold = 0.4
        camera.bloomBlurRadius = 16.0
        camera.motionBlurIntensity = 0.5 // Cinematic feel
        camera.vignettingPower = 1.0
        camera.vignettingIntensity = 0.4
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 60, 160)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // Cinematic Orbit
        let pivot = SCNNode()
        pivot.addChildNode(cameraNode)
        scene.rootNode.addChildNode(pivot)
        pivot.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 240)))
        
        // 2. Lighting - "Space" lighting (Single massive source)
        let sunLight = SCNLight()
        sunLight.type = .omni // Omni for system-wide, but behaves like point in space
        sunLight.intensity = 5000 // In Lumens (physically based)
        sunLight.temperature = 5800 // Solar temp
        sunLight.castsShadow = true
        
        let sunLightNode = SCNNode()
        sunLightNode.light = sunLight
        sunLightNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(sunLightNode)
    }
    
    private func setupStarfield() {
        // High density, varying depth starfield
        let starNode = SCNNode()
        
        // Background dust/nebula clouds (simulated with thousands of particles)
        let dustSystem = SCNParticleSystem()
        dustSystem.birthRate = 0
        dustSystem.loops = false
        dustSystem.particleLifeSpan = 1e9
        dustSystem.emitterShape = SCNSphere(radius: 800)
        dustSystem.particleSize = 4.0 // Large soft sprites
        dustSystem.particleColor = PlatformColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 0.2)
        dustSystem.blendMode = .additive
        
        // Actual Stars
        let starSystem = SCNParticleSystem()
        starSystem.birthRate = 0
        starSystem.loops = false
        starSystem.particleLifeSpan = 1e9
        starSystem.emitterShape = SCNSphere(radius: 700)
        starSystem.particleSize = 0.2
        starSystem.particleColor = PlatformColor.white
        starSystem.particleColorVariation = SCNVector4(0.2, 0.2, 0.5, 0)
        
        // Manually inhibit emission to spawn once
        let dustNode = SCNNode()
        dustNode.addParticleSystem(dustSystem)
        scene.rootNode.addChildNode(dustNode)
        
        // Generate stars manually for placement control if needed, 
        // but particle system efficient for 10k stars
        for _ in 0..<5000 {
            let s = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 0.05...0.2)))
            s.geometry?.firstMaterial?.emission.contents = PlatformColor.white
            s.position = SCNVector3(
                Float.random(in: -700...700),
                Float.random(in: -700...700),
                Float.random(in: -700...700)
            )
            starNode.addChildNode(s)
        }
        scene.rootNode.addChildNode(starNode)
    }
    
    private func setupSun() {
        // Core
        let geo = SCNSphere(radius: 12)
        geo.segmentCount = 96
        let mat = SCNMaterial()
        mat.diffuse.contents = PlatformColor.black
        mat.emission.contents = PlatformColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        mat.lightingModel = .physicallyBased
        
        // Add shader for surface ripples
        mat.shaderModifiers = [.fragment: sunShaderModifier]
        
        sunNode = SCNNode(geometry: geo)
        sunNode.geometry?.materials = [mat]
        
        // 2. Corona (Volumetric Glow Shell)
        let corona = SCNNode(geometry: SCNSphere(radius: 14))
        corona.opacity = 0.4
        let cMat = SCNMaterial()
        cMat.diffuse.contents = PlatformColor.orange
        cMat.emission.contents = PlatformColor.orange
        cMat.transparent.contents = PlatformColor.black // Additive blending simulation
        cMat.blendMode = .add
        corona.geometry?.materials = [cMat]
        sunNode.addChildNode(corona)
        
        // 3. Solar Flares (Particles)
        let flares = SCNParticleSystem()
        flares.birthRate = 200
        flares.particleLifeSpan = 2.0
        flares.emitterShape = SCNSphere(radius: 12.5)
        flares.particleSize = 0.5
        flares.particleColor = PlatformColor.yellow
        flares.blendMode = .additive
        sunNode.addParticleSystem(flares)
        
        scene.rootNode.addChildNode(sunNode)
    }
    
    private func setupPlanets() {
        for planet in PlanetType.allCases {
            let pivot = SCNNode()
            scene.rootNode.addChildNode(pivot)
            
            // Planet Core (PBR)
            let pGeo = SCNSphere(radius: planet.radius)
            pGeo.segmentCount = 72
            let pMat = SCNMaterial()
            pMat.lightingModel = .physicallyBased
            pMat.diffuse.contents = planet.baseColor
            pMat.roughness.contents = 0.6 // Consistent matte/gloss mix
            pMat.metalness.contents = 0.0
            
            // Add subtle detail noise if possible, otherwise solid colors for now
            // PBR handles the lighting interaction beautifully
            
            let pNode = SCNNode(geometry: pGeo)
            pNode.geometry?.materials = [pMat]
            pNode.position = SCNVector3(planet.distance, 0, 0)
            
            // Atmosphere Shell
            let atmosGeo = SCNSphere(radius: planet.radius * 1.05)
            atmosGeo.segmentCount = 72
            let atmosMat = SCNMaterial()
            atmosMat.diffuse.contents = planet.atmosphereColor
            atmosMat.emission.contents = PlatformColor.black // Emission comes from shader
            atmosMat.transparent.contents = PlatformColor(white: 0.0, alpha: 1.0) // Handled by shader
            
            // Inject Atmosphere Shader
            atmosMat.shaderModifiers = [.fragment: atmosphereShaderModifier]
            
            let atmosNode = SCNNode(geometry: atmosGeo)
            atmosNode.geometry?.materials = [atmosMat]
            pNode.addChildNode(atmosNode)
            
            // Rings for Saturn
            if planet == .saturn {
                let ring = SCNTorus(ringRadius: planet.radius * 1.8, pipeRadius: planet.radius * 0.8)
                let rMat = SCNMaterial()
                rMat.diffuse.contents = PlatformColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.6)
                rMat.emission.contents = PlatformColor(red: 0.2, green: 0.1, blue: 0.0, alpha: 1.0)
                let ringNode = SCNNode(geometry: ring)
                ringNode.scale = SCNVector3(1, 0.02, 1) // Flatten
                ringNode.geometry?.materials = [rMat]
                pNode.addChildNode(ringNode)
            }
            
            // High-Tech UI Label (Holographic)
            let text = SCNText(string: planet.rawValue, extrusionDepth: 0.1)
            text.font = UIFont.systemFont(ofSize: 1.0, weight: .heavy)
            let tMat = SCNMaterial()
            tMat.emission.contents = planet.atmosphereColor
            tMat.diffuse.contents = PlatformColor.white
            let textNode = SCNNode(geometry: text)
            textNode.geometry?.materials = [tMat]
            textNode.scale = SCNVector3(0.8, 0.8, 0.8)
            
            // Center & Position Label
            let (min, max) = textNode.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation((max.x - min.x)/2, min.y, 0)
            textNode.position = SCNVector3(0, planet.radius + 2.0, 0)
            textNode.constraints = [SCNBillboardConstraint()]
            
            pNode.addChildNode(textNode)
            pivot.addChildNode(pNode)
            
            // Planet Rotation (Spin)
            pNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 20 + Double.random(in: 0...10))))
            
            // Orbit Rotation
            pivot.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120 / planet.speed)))
            
            planetNodes[planet] = pNode
        }
    }
    
    private func setupOrbits() {
        for planet in PlanetType.allCases {
            // Thin, tech-like orbit lines
            let ring = SCNTorus(ringRadius: CGFloat(planet.distance), pipeRadius: 0.08)
            let rMat = SCNMaterial()
            rMat.diffuse.contents = PlatformColor(white: 0.1, alpha: 0.2)
            rMat.emission.contents = PlatformColor(white: 0.1, alpha: 1.0)
            let rNode = SCNNode(geometry: ring)
            rNode.geometry?.materials = [rMat]
            scene.rootNode.addChildNode(rNode)
        }
    }
    
    func updateSunState(_ state: OrbState) {
        let color: PlatformColor
        switch state {
        case .idle: color = PlatformColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        case .listening: color = PlatformColor.cyan
        case .processing: color = PlatformColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 1.0)
        case .success: color = PlatformColor.green
        case .error: color = PlatformColor.red
        }
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        sunNode.geometry?.materials.first?.emission.contents = color
        SCNTransaction.commit()
    }
}
