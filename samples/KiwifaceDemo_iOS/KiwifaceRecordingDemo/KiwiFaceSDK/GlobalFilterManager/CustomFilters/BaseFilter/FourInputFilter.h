#import "GPUImageThreeInputFilter.h"
#import "KWRenderProtocol.h"

extern NSString *const kFourInputTextureVertexShaderString;

@interface FourInputFilter : GPUImageThreeInputFilter <KWRenderProtocol>
{
    GPUImageFramebuffer *fourthInputFramebuffer;

    GLint filterFourthTextureCoordinateAttribute;
    GLint filterInputTextureUniform4;
    GPUImageRotationMode inputRotation4;
    GLuint filterSourceTexture4;
    CMTime fourthFrameTime;

    BOOL hasSetThirdTexture, hasReceivedFourthFrame, fourthFrameWasVideo;
    BOOL fourthFrameCheckDisabled;
}

- (void)disableFourthFrameCheck;

@end
