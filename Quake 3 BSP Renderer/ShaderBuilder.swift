//
//  ShaderBuilder.swift
//  Quake 3 BSP Renderer
//
//  Created by Thomas Brunoli on 10/03/2016.
//  Copyright © 2016 Thomas Brunoli. All rights reserved.
//

import Foundation
import Mustache

func buildShaderLibrary(shader: Q3Shader, stage: Q3ShaderStage) -> String {
    let template = try! Template(named: "shaderTemplate")
    return try! template.render()
}