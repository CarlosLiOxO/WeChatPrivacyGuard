#import "EnrollmentProgressEvaluator.h"
#import <math.h>

BOOL EnrollmentPoseAcceptsSample(NSUInteger sampleIndex, NSNumber *yaw) {
    double angle = yaw.doubleValue;
    switch (sampleIndex) {
        case 0: return yaw && fabs(angle) < 0.18;
        case 1:
        case 5:
            return yaw && angle >= -0.36 && angle < -0.12;
        case 3:
        case 7:
            return yaw && angle > 0.12 && angle <= 0.36;
        default: return yaw && fabs(angle) < 0.20;
    }
}
