//
//  Shader.fsh
//  pudding
//
//  Created by 黒岩亮 on 2016/12/23.
//  Copyright © 2016年 黒岩亮. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
