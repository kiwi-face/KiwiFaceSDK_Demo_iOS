#import "GPUImageFilterGroup.h"
#import "KWRenderProtocol.h"
#import "GPUImage.h"
#import "FourInputFilter.h"

@interface HudsonFilter : FourInputFilter

@end

@interface Hudson : GPUImageFilterGroup <KWRenderProtocol>
{
    GPUImagePicture *imageSource1;
    GPUImagePicture *imageSource2;
    GPUImagePicture *imageSource3;
}

@property(nonatomic, readonly) BOOL needTrackData;

@end
