//
//  RGBACopier.m
//  OpenGLRenderer
//
//  Created by apple on 2017/2/9.
//  Copyright © 2017年 xiaokai.zhan. All rights reserved.
//

#import "RGBAFrameCopier.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = position;
     v_texcoord = texcoord.xy;
 }
);

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, v_texcoord);
 }
);

@implementation RGBAFrameCopier
{
    NSInteger                           frameWidth;
    NSInteger                           frameHeight;
    
    GLuint                              filterProgram;
    GLint                               filterPositionAttribute;
    GLint                               filterTextureCoordinateAttribute;
    GLint                               filterInputTextureUniform;
    
    GLuint                              _inputTexture;
}
- (BOOL) prepareRender:(NSInteger)textureWidth height:(NSInteger)textureHeight;
{
    BOOL ret = NO;
    frameWidth = textureWidth;
    frameHeight = textureHeight;
    if([self buildProgram:vertexShaderString fragmentShader:rgbFragmentShaderString]) {
        /*
            下面是创建并设置纹理的过程。设置会一直跟随_inputTexture这个纹理。
         */
        // 创建一个纹理对象，创建好的纹理(是一个id)赋值给_inputTexture
        glGenTextures(1, &_inputTexture);
        // 绑定该创建的纹理id，这样子openGLES才知道该操作哪个纹理
        glBindTexture(GL_TEXTURE_2D, _inputTexture);
        /*
         将图片上传到纹理之前，要设置纹理对象渲染的参数
         */
        // 设置放大和缩小. GL_LINEAR双线性过滤
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // 设置坐标系映射
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        // 把图片的内容存到纹理上。openGL大部分纹理只接受RGBA类型，最后一个参数代表RGBA数据，这里传的0，所以这里并没有真正把图片内容放到新建的纹理上。
        // 本来下面这行代码不是注释掉的，因为判断出没有把图片放到纹理上，所以下面这行代码其实不起任何作用，所以把代码注释掉以后，没有任何影响。
//        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        // 渲染过后，解绑这个纹理
        glBindTexture(GL_TEXTURE_2D, 0);
        ret = YES;
    }
    return ret;
}

/*
    对应书中P96的图4-5，该方法创建一个显卡的可执行程序(programe)
    1 首先是glCreateProgram
    2 然后生成vertex shader和fragment shader：
        1. glCreateShader
        2. glShaderSource，为1中创建的shader添加源码
        3. glCompileShader
        4. glGetShaderiv，检查compile是否成功
    3 glAttachShader
    4 glLinkProgram
    5 glUserProgram 在- (void) renderFrame:(uint8_t*) rgbaFrame中呼叫
 */
- (BOOL) buildProgram:(NSString*) vertexShader fragmentShader:(NSString*) fragmentShader;
{
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    filterProgram = glCreateProgram();
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShader);
    if (!vertShader)
        goto exit;
    fragShader = compileShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (!fragShader)
        goto exit;
    
    glAttachShader(filterProgram, vertShader);
    glAttachShader(filterProgram, fragShader);
    
    glLinkProgram(filterProgram);
    
    // 获得program的"position" attribute的index
    filterPositionAttribute = glGetAttribLocation(filterProgram, "position");
    // 获得program的"textcoord" attribute的index
    filterTextureCoordinateAttribute = glGetAttribLocation(filterProgram, "texcoord");
    /*
        glGetUniformLocation returns an integer that represents the location of a specific uniform variable within a program object
        https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glGetUniformLocation.xhtml
     */
    // 获得"inputImageTexture"的location
    filterInputTextureUniform = glGetUniformLocation(filterProgram, "inputImageTexture");
    
    GLint status;
    glGetProgramiv(filterProgram, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", filterProgram);
        goto exit;
    }
    result = validateProgram(filterProgram);
exit:
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    return result;
}

// 对应glUserProgram
- (void) renderFrame:(uint8_t*) rgbaFrame;
{
    // 使用该显卡的可执行程序
    glUseProgram(filterProgram);
    //
    glClearColor(0.0f, 0.0f, 1.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // 绑定纹理，告诉openGL现在操作这个纹理。纹理在-prepareRender方法中配置过。
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    // 把图片的内容存到纹理上。openGL大部分纹理只接受RGBA类型，最后一个参数代表RGBA数据
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)frameWidth, (GLsizei)frameHeight,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, rgbaFrame);
    
    static const GLfloat imageVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    /*
     glVertexAttribPointer — define an array of generic vertex attribute data
     
     To enable and disable a generic vertex attribute array, call glEnableVertexAttribArray and glDisableVertexAttribArray with index. If enabled, the generic vertex attribute array is used when glDrawArrays, glMultiDrawArrays, glDrawElements, glMultiDrawElements, or glDrawRangeElements is called.
     */
    
    // 设置物体坐标, filterPositionAttribute从glGetAttribLocation(filterProgram, "position")获得
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(filterPositionAttribute);
    // 设置纹理坐标，filterTextureCoordinateAttribute从glGetAttribLocation(filterProgram, "texcoord")获得
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, noRotationTextureCoordinates);
    glEnableVertexAttribArray(filterTextureCoordinateAttribute);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    
    /*
        glUniform modifies the value of a uniform variable or a uniform variable array. The location of the uniform variable to be modified is specified by location, which should be a value returned by glGetUniformLocation. glUniform operates on the program object that was made part of current state by calling glUseProgram.
     https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/glUniform.xhtml
     */
    
    // filterInputTextureUniform从glGetUniformLocation(filterProgram, "inputImageTexture")获得
    // 下面这句注释掉也可以正常渲染
    glUniform1i(filterInputTextureUniform, 0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void) releaseRender;
{
    if (filterProgram) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
    if(_inputTexture) {
        glDeleteTextures(1, &_inputTexture);
    }
}
@end
