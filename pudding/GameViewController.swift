//
//  GameViewController.swift
//  pudding
//
//  Created by kakira on 2015/09/07.
//  Copyright © 2015年 kakira. All rights reserved.
//

import GLKit
import OpenGLES

func BUFFER_OFFSET(_ i: Int) -> UnsafeRawPointer? {
    return UnsafeRawPointer(bitPattern: i)
}

let UNIFORM_MODELVIEWPROJECTION_MATRIX = 0
let UNIFORM_NORMAL_MATRIX = 1
var uniforms = [GLint](repeating: 0, count: 2)

class GameViewController: GLKViewController {
    
    var program: GLuint = 0
    
    var modelViewProjectionMatrix:GLKMatrix4 = GLKMatrix4Identity
    var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
    var rotation: Float = 0.0
    
    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    var indexBuffer: GLuint = 0
    
    var context: EAGLContext? = nil
    var effect: GLKBaseEffect? = nil
    
    var pudding: [Vertex] = []
    var gPuddingVertexData: [GLfloat] = []
    var gPuddingIndexData: [GLuint] = []
    var touchX: CGFloat = 0
    var touchY: CGFloat = 0
    var touching: Bool = false
    var cameraAzimuth: GLfloat = 90.0
    var cameraElevation: GLfloat = 30.0
    var cameraDistance: GLfloat = 4.0
    
    var kSpring: GLfloat = 0.12
    var puddingStrength: GLfloat = 0.95
    var forceStrength: GLfloat = 0.10
    
    class Vector3d {
        var x: GLfloat
        var y: GLfloat
        var z: GLfloat
        init(x: GLfloat, y: GLfloat, z: GLfloat) {
            self.x = x
            self.y = y
            self.z = z
        }
        init(v: Vector3d) {
            self.x = v.x
            self.y = v.y
            self.z = v.z
        }
    }
    
    class Vertex {
        var p: Vector3d
        var t: Vector3d
        var v: Vector3d
        var color: Vector3d
        init(p: Vector3d, t: Vector3d, color: Vector3d) {
            self.p = p
            self.t = t
            self.v = Vector3d(x: 0, y: 0, z: 0)
            self.color = color
        }
    }
    
    let pi = GLfloat(Double.pi)
    let numP = 50
    let numC = 20
    let numTop = 10
    
    deinit {
        self.tearDownGL()
        
        if EAGLContext.current() === self.context {
            EAGLContext.setCurrent(nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.context = EAGLContext(api: .openGLES2)
        
        if !(self.context != nil) {
            print("Failed to create ES context")
        }
        
        let view = self.view as! GLKView
        view.context = self.context!
        view.drawableDepthFormat = .format24
        self.preferredFramesPerSecond = 60
        
        //    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]
        //                                            initWithTarget:self action:@selector(handlePinchGesture:)];
        //    [self.view addGestureRecognizer:pinchGesture];
        //    [pinchGesture release];
        
        let myPinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(GameViewController.pinchGesture(_:)))
        self.view.addGestureRecognizer(myPinchGesture)
        
        
        self.setupGL()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        if self.isViewLoaded && (self.view.window != nil) {
            self.view = nil
            
            self.tearDownGL()
            
            if EAGLContext.current() === self.context {
                EAGLContext.setCurrent(nil)
            }
            self.context = nil
        }
    }
    
    func pinchGesture(_ sender: AnyObject) {
        touching = false
        let pinch = sender as! UIPinchGestureRecognizer
        let v = pinch.velocity
        
        
        if (!v.isNaN) {
            cameraDistance -= (GLfloat(v) - 1) * 0.1
        }
        if cameraDistance < 2.0 {
            cameraDistance = 2.0
        } else if cameraDistance > 20.0 {
            cameraDistance = 20.0
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let location = touch?.location(in: self.view)
        super.touchesBegan(touches, with: event)
        touching = true
        touchX = location!.x
        touchY = location!.y
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let location = touch?.location(in: self.view)
        super.touchesEnded(touches, with: event)
        touching = false
        touchX = location!.x
        touchY = location!.y
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let newLocation = touch?.location(in: self.view)
        super.touchesMoved(touches, with: event)
        touchX = newLocation!.x
        touchY = newLocation!.y
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let svcl: SettingViewController = segue.destination as! SettingViewController
        svcl.gvcl = self
    }
    
    func setupGL() {
        EAGLContext.setCurrent(self.context)
        
        self.effect = GLKBaseEffect()
        /*
         self.effect!.light0.enabled = GLboolean(GL_TRUE)
         self.effect!.light0.diffuseColor = GLKVector4Make(1.0, 0.4, 0.4, 1.0)
         */
        generatePudding()
        updatePuddingVertices()
        
        glEnable(GLenum(GL_DEPTH_TEST))
        
        glGenVertexArraysOES(1, &vertexArray)
        glBindVertexArrayOES(vertexArray)
        
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gPuddingVertexData.count), BUFFER_OFFSET(0), GLenum(GL_STREAM_DRAW))
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(0))
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.color.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.color.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(12))
        
        glGenBuffers(1, &indexBuffer)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLuint>.size * gPuddingIndexData.count), &gPuddingIndexData, GLenum(GL_STATIC_DRAW))
        
        glBindVertexArrayOES(0);
    }
    
    func tearDownGL() {
        EAGLContext.setCurrent(self.context)
        
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteVertexArraysOES(1, &vertexArray)
        
        self.effect = nil
        
        if program != 0 {
            glDeleteProgram(program)
            program = 0
        }
    }
    
    func generatePudding() {
        for i in 0..<numC {
            var r : GLfloat
            var color: Vector3d
            if i > numTop {
                r = 1 + 0.05 * GLfloat(i - numTop)
                color = Vector3d(x: 255.0 / 255, y: 212.0 / 255, z: 0 / 255)
            } else {
                r = 0.1 * GLfloat(i)
                color = Vector3d(x: 158.0 / 255, y: 67.0 / 255, z: 0 / 255)
            }
            for j in 0..<numP {
                let x = r * cos(2.0 * pi / GLfloat(numP) * GLfloat(j))
                let y = i < numTop ? 0.5 : 0.5 - GLfloat(i - numTop) * 0.1
                let z = r * sin(2 * pi / GLfloat(numP) * GLfloat(j))
                let p = Vector3d(x: x * 0.1, y: y * 0.1, z: z * 0.1)
                let t = Vector3d(x: x, y: y, z: z)
                pudding.append(Vertex(p: p, t: t, color: color))
            }
        }
        for i in 0..<numC - 1 {
            for j in 0...numP {
                let jj = j % numP
                let i1: GLuint = GLuint(i * numP + jj)
                let i2: GLuint = GLuint((i + 1) * numP + jj)
                gPuddingIndexData += [i1, i2]
            }
        }
        for _ in 0..<pudding.count {
            gPuddingVertexData.append(0.0)
            gPuddingVertexData.append(0.0)
            gPuddingVertexData.append(0.0)
            gPuddingVertexData.append(0.0)
            gPuddingVertexData.append(0.0)
            gPuddingVertexData.append(0.0)
        }
    }
    
    func updatePuddingVertices() {
        for i in 0..<pudding.count {
            let v = pudding[i]
            gPuddingVertexData[i * 6 + 0] = v.p.x
            gPuddingVertexData[i * 6 + 1] = v.p.y
            gPuddingVertexData[i * 6 + 2] = v.p.z
            gPuddingVertexData[i * 6 + 3] = v.color.x
            gPuddingVertexData[i * 6 + 4] = v.color.y
            gPuddingVertexData[i * 6 + 5] = v.color.z
        }
        /*
         for i in 0..<numC - 1 {
         for j in 0...numP {
         let jj = j % numP
         let v1 = pudding[i * numP + jj]
         let v2 = pudding[(i + 1) * numP + jj]
         gPuddingVertexData += [v1.p.x, v1.p.y, v1.p.z, v1.color.x, v1.color.y, v1.color.z]
         gPuddingVertexData += [v2.p.x, v2.p.y, v2.p.z, v2.color.x, v2.color.y, v2.color.z]
         }
         }
         */
        
    }
    
    func ret3dPos(x: GLfloat, y: GLfloat) -> Vector3d {
        let width = GLfloat(self.view!.bounds.size.width)
        let height = GLfloat(self.view!.bounds.size.height)
        var x3d = (x / width - 0.5) * 4
        let y3d = -(y / height - 0.5) * 4
        var z3d = GLfloat(0)
        
        let x_ = x3d
        let z_ = z3d
        let RAD = (pi / 180.0)
        
        x3d = x_ * cos((cameraAzimuth - 90) * RAD) - z_ * sin((cameraAzimuth - 90) * RAD)
        z3d = x_ * sin((cameraAzimuth - 90) * RAD) + z_ * cos((cameraAzimuth - 90) * RAD)
        return Vector3d(x: x3d, y: y3d, z: z3d)
    }
    
    func movePuddingVertices() {
        let m: Vector3d = ret3dPos(x: GLfloat(touchX), y: GLfloat(touchY))
        
        for i in 0..<numP * numC {
            let vert = pudding[i]
            vert.p.x += vert.v.x
            vert.p.y += vert.v.y
            vert.p.z += vert.v.z
            
            vert.v.x *= puddingStrength
            vert.v.y *= puddingStrength
            vert.v.z *= puddingStrength
            
            let dm = Vector3d(x: vert.p.x - m.x, y: vert.p.y - m.y, z: vert.p.z - m.z)
            var distm: GLfloat = GLfloat(sqrt(dm.x * dm.x + dm.y * dm.y + dm.z * dm.z))
            if distm < 1e-8 {
                distm = GLfloat(1e-8)
            }
            let dp = Vector3d(x: vert.p.x - vert.t.x, y: vert.p.y - vert.t.y, z: vert.p.z - vert.t.z)
            
            
            if touching {
                vert.v.x += forceStrength * (1.0 / distm) * dm.x
                vert.v.y += forceStrength * (1.0 / distm) * dm.y
                vert.v.z += forceStrength * (1.0 / distm) * dm.z
            }
            
            vert.v.x -= kSpring * dp.x
            vert.v.y -= kSpring * dp.y
            vert.v.z -= kSpring * dp.z
        }
    }
    
    // MARK: - GLKView and GLKViewController delegate methods
    
    func update() {
        
        let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1, 100.0)
        
        movePuddingVertices()
        updatePuddingVertices()
        
        
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), GLintptr(0), MemoryLayout<GLfloat>.size * gPuddingVertexData.count, &gPuddingVertexData)
        //glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(sizeof(GLfloat) * gPuddingVertexData.count), &gPuddingVertexData, GLenum(GL_STREAM_DRAW))
        
        self.effect?.transform.projectionMatrix = projectionMatrix
        let RAD = (pi / 180.0)
        
        let baseModelViewMatrix = GLKMatrix4MakeLookAt(
            cameraDistance * cos(cameraAzimuth * RAD) * cos(cameraElevation * RAD),
            cameraDistance * sin(cameraElevation * RAD),
            cameraDistance * sin(cameraAzimuth * RAD) * cos(cameraElevation * RAD),
            0.0, 0.0, 0.0,
            0.0, 1.0, 0.0)
        // Compute the model view matrix for the object rendered with GLKit
        var modelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 0.0)
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, 0.0, 1.0, 1.0, 1.0)
        modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix)
        
        self.effect?.transform.modelviewMatrix = modelViewMatrix
        
        rotation += Float(self.timeSinceLastUpdate * 0.5)
        
        
    }
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        
        
        glClearColor(0.65, 0.65, 0.65, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        glBindVertexArrayOES(vertexArray)
        /*
         glEnableClientState(GLenum(GL_NORMAL_ARRAY));
         glBindBuffer(GL_ARRAY_BUFFER, nrmID);
         glNormalPointer(GL_FLOAT, 0, 0);
         */
        
        // Render the object with GLKit
        self.effect?.prepareToDraw()
        /*
         for i in 0..<numC - 1 {
         glDrawArrays(GLenum(GL_TRIANGLE_STRIP) , GLsizei(2 * i * (numP + 1)), GLsizei(2 * (numP + 1)))
         }
         */
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        /*
         glDrawElements(GLenum(GL_TRIANGLE_STRIP), GLsizei(gPuddingIndexData.count), GLenum(GL_UNSIGNED_INT), BUFFER_OFFSET(0))
         */
        
        for i in 0..<numC - 1 {
            glDrawElements(GLenum(GL_TRIANGLE_STRIP), GLsizei(2 * (numP + 1)), GLenum(GL_UNSIGNED_INT), BUFFER_OFFSET(MemoryLayout<GLuint>.size * 2 * i * (numP + 1)))
        }
        
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        
    }
    
    // MARK: -  OpenGL ES 2 shader compilation
    /*
     func loadShaders() -> Bool {
     var vertShader: GLuint = 0
     var fragShader: GLuint = 0
     var vertShaderPathname: String
     var fragShaderPathname: String
     
     // Create shader program.
     program = glCreateProgram()
     
     // Create and compile vertex shader.
     vertShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "vsh")!
     if self.compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
     print("Failed to compile vertex shader")
     return false
     }
     
     // Create and compile fragment shader.
     fragShaderPathname = NSBundle.mainBundle().pathForResource("Shader", ofType: "fsh")!
     if !self.compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
     print("Failed to compile fragment shader");
     return false
     }
     
     // Attach vertex shader to program.
     glAttachShader(program, vertShader)
     
     // Attach fragment shader to program.
     glAttachShader(program, fragShader)
     
     // Bind attribute locations.
     // This needs to be done prior to linking.
     glBindAttribLocation(program, GLuint(GLKVertexAttrib.Position.rawValue), "position")
     glBindAttribLocation(program, GLuint(GLKVertexAttrib.Normal.rawValue), "normal")
     
     // Link program.
     if !self.linkProgram(program) {
     print("Failed to link program: \(program)")
     
     if vertShader != 0 {
     glDeleteShader(vertShader)
     vertShader = 0
     }
     if fragShader != 0 {
     glDeleteShader(fragShader)
     fragShader = 0
     }
     if program != 0 {
     glDeleteProgram(program)
     program = 0
     }
     
     return false
     }
     
     // Get uniform locations.
     uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(program, "modelViewProjectionMatrix")
     uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(program, "normalMatrix")
     
     // Release vertex and fragment shaders.
     if vertShader != 0 {
     glDetachShader(program, vertShader)
     glDeleteShader(vertShader);
     }
     if fragShader != 0 {
     glDetachShader(program, fragShader);
     glDeleteShader(fragShader);
     }
     
     return true
     }
     
     
     func compileShader(inout shader: GLuint, type: GLenum, file: String) -> Bool {
     var status: GLint = 0
     var source: UnsafePointer<Int8>
     do {
     source = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding).UTF8String
     } catch {
     print("Failed to load vertex shader")
     return false
     }
     var castSource = UnsafePointer<GLchar>(source)
     
     shader = glCreateShader(type)
     glShaderSource(shader, 1, &castSource, nil)
     glCompileShader(shader)
     
     //#if defined(DEBUG)
     //        var logLength: GLint = 0
     //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength);
     //        if logLength > 0 {
     //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
     //            glGetShaderInfoLog(shader, logLength, &logLength, log);
     //            NSLog("Shader compile log: \n%s", log);
     //            free(log)
     //        }
     //#endif
     
     glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
     if status == 0 {
     glDeleteShader(shader);
     return false
     }
     return true
     }
     
     func linkProgram(prog: GLuint) -> Bool {
     var status: GLint = 0
     glLinkProgram(prog)
     
     //#if defined(DEBUG)
     //        var logLength: GLint = 0
     //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength);
     //        if logLength > 0 {
     //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
     //            glGetShaderInfoLog(shader, logLength, &logLength, log);
     //            NSLog("Shader compile log: \n%s", log);
     //            free(log)
     //        }
     //#endif
     
     glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
     if status == 0 {
     return false
     }
     
     return true
     }
     
     func validateProgram(prog: GLuint) -> Bool {
     var logLength: GLsizei = 0
     var status: GLint = 0
     
     glValidateProgram(prog)
     glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
     if logLength > 0 {
     var log: [GLchar] = [GLchar](count: Int(logLength), repeatedValue: 0)
     glGetProgramInfoLog(prog, logLength, &logLength, &log)
     print("Program validate log: \n\(log)")
     }
     
     glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
     var returnVal = true
     if status == 0 {
     returnVal = false
     }
     return returnVal
     }
     */
}
