/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "GDTCCTLibrary/Private/GDTCCTPrioritizer.h"

#import <GoogleDataTransport/GDTCORConsoleLogger.h>
#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORRegistrar.h>
#import <GoogleDataTransport/GDTCORStoredEvent.h>
#import <GoogleDataTransport/GDTCORTargets.h>

const static int64_t kMillisPerDay = 8.64e+7;

@implementation GDTCCTPrioritizer

+ (void)load {
  GDTCCTPrioritizer *prioritizer = [GDTCCTPrioritizer sharedInstance];
  [[GDTCORRegistrar sharedInstance] registerPrioritizer:prioritizer target:kGDTCORTargetCCT];
  [[GDTCORRegistrar sharedInstance] registerPrioritizer:prioritizer target:kGDTCORTargetFLL];
  [[GDTCORRegistrar sharedInstance] registerPrioritizer:prioritizer target:kGDTCORTargetCSH];
}

+ (instancetype)sharedInstance {
  static GDTCCTPrioritizer *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GDTCCTPrioritizer alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create("com.google.GDTCCTPrioritizer", DISPATCH_QUEUE_SERIAL);
    _CCTEvents = [[NSMutableSet alloc] init];
    _FLLEvents = [[NSMutableSet alloc] init];
    _CSHEvents = [[NSMutableSet alloc] init];
  }
  return self;
}

#pragma mark - GDTCORPrioritizer Protocol

- (void)prioritizeEvent:(GDTCORStoredEvent *)event {
  dispatch_async(_queue, ^{
    switch (event.target.intValue) {
      case kGDTCORTargetCCT:
        [self.CCTEvents addObject:event];
        break;

      case kGDTCORTargetFLL:
        [self.FLLEvents addObject:event];
        break;

      case kGDTCORTargetCSH:
        [self.CSHEvents addObject:event];
        break;

      default:
        GDTCORLogDebug("GDTCCTPrioritizer doesn't support target %d", event.target.intValue);
        break;
    }
  });
}

- (GDTCORUploadPackage *)uploadPackageWithTarget:(GDTCORTarget)target
                                      conditions:(GDTCORUploadConditions)conditions {
  GDTCORUploadPackage *package = [[GDTCORUploadPackage alloc] initWithTarget:target];
  dispatch_sync(_queue, ^{
    NSSet<GDTCORStoredEvent *> *eventsThatWillBeSent = [self eventsForTarget:target
                                                                  conditions:conditions];
    package.events = eventsThatWillBeSent;
  });
  GDTCORLogDebug("CCT: %lu events are in the upload package", (unsigned long)package.events.count);
  return package;
}

#pragma mark - Private helper methods

/** The different possible quality of service specifiers. High values indicate high priority. */
typedef NS_ENUM(NSInteger, GDTCCTQoSTier) {
  /** The QoS tier wasn't set, and won't ever be sent. */
  GDTCCTQoSDefault = 0,

  /** This event is internal telemetry data that should not be sent on its own if possible. */
  GDTCCTQoSTelemetry = 1,

  /** This event should be sent, but in a batch only roughly once per day. */
  GDTCCTQoSDaily = 2,

  /** This event should only be uploaded on wifi. */
  GDTCCTQoSWifiOnly = 5,
};

/** Converts a GDTCOREventQoS to a GDTCCTQoS tier.
 *
 * @param qosTier The GDTCOREventQoS value.
 * @return A static NSNumber that represents the CCT QoS tier.
 */
FOUNDATION_STATIC_INLINE
NSNumber *GDTCCTQosTierFromGDTCOREventQosTier(GDTCOREventQoS qosTier) {
  switch (qosTier) {
    case GDTCOREventQoSWifiOnly:
      return @(GDTCCTQoSWifiOnly);
      break;

    case GDTCOREventQoSTelemetry:
      // falls through.
    case GDTCOREventQoSDaily:
      return @(GDTCCTQoSDaily);
      break;

    default:
      return @(GDTCCTQoSDefault);
      break;
  }
}

/** Constructs a set of events for upload to CCT, FLL, or CSH backends. These backends are
 * request-proto and batching compatible, so they construct event batches the same way.
 *
 * @param conditions The set of conditions the upload package should be made under.
 * @param target The target backend.
 * @return A set of events for the target.
 */
- (NSSet<GDTCORStoredEvent *> *)eventsForTarget:(GDTCORTarget)target
                                     conditions:(GDTCORUploadConditions)conditions {
  GDTCORClock __strong **timeOfLastDailyUpload = NULL;
  NSSet<GDTCORStoredEvent *> *eventsToFilter;
  switch (target) {
    case kGDTCORTargetCCT:
      eventsToFilter = self.CCTEvents;
      timeOfLastDailyUpload = &self->_CCTTimeOfLastDailyUpload;
      break;

    case kGDTCORTargetFLL:
      eventsToFilter = self.FLLEvents;
      timeOfLastDailyUpload = &self->_FLLOfLastDailyUpload;
      break;

    case kGDTCORTargetCSH:
      // This backend doesn't batch and uploads all events as soon as possible without respect to
      // any upload condition.
      return self.CSHEvents;
      break;

    default:
      // Return an empty set.
      return [[NSSet alloc] init];
      break;
  }

  NSMutableSet<GDTCORStoredEvent *> *eventsThatWillBeSent = [[NSMutableSet alloc] init];
  // A high priority event effectively flushes all events to be sent.
  if ((conditions & GDTCORUploadConditionHighPriority) == GDTCORUploadConditionHighPriority) {
    GDTCORLogDebug("%@", @"CCT: A high priority event is flushing all events.");
    return eventsToFilter;
  }

  // If on wifi, upload logs that are ok to send on wifi.
  if ((conditions & GDTCORUploadConditionWifiData) == GDTCORUploadConditionWifiData) {
    [eventsThatWillBeSent unionSet:[self logEventsOkToSendOnWifi:eventsToFilter]];
    GDTCORLogDebug("%@", @"CCT: events ok to send on wifi are being added to the upload package");
  } else {
    [eventsThatWillBeSent unionSet:[self logEventsOkToSendOnMobileData:eventsToFilter]];
    GDTCORLogDebug("%@", @"CCT: events ok to send on mobile are being added to the upload package");
  }

  // If it's been > 24h since the last daily upload, upload logs with the daily QoS.
  if (*timeOfLastDailyUpload) {
    int64_t millisSinceLastUpload =
        [GDTCORClock snapshot].timeMillis - (*timeOfLastDailyUpload).timeMillis;
    if (millisSinceLastUpload > kMillisPerDay) {
      [eventsThatWillBeSent unionSet:[self logEventsOkToSendDaily:eventsToFilter]];
      GDTCORLogDebug("%@", @"CCT: events ok to send daily are being added to the upload package");
    }
  } else {
    *timeOfLastDailyUpload = [GDTCORClock snapshot];
    [eventsThatWillBeSent unionSet:[self logEventsOkToSendDaily:eventsToFilter]];
    GDTCORLogDebug("%@", @"CCT: events ok to send daily are being added to the upload package");
  }
  return eventsThatWillBeSent;
}

/** Returns a set of logs that are ok to upload whilst on mobile data.
 *
 * @note This should be called from a thread safe method.
 * @return A set of logs that are ok to upload whilst on mobile data.
 */
- (NSSet<GDTCORStoredEvent *> *)logEventsOkToSendOnMobileData:(NSSet<GDTCORStoredEvent *> *)events {
  return [events objectsPassingTest:^BOOL(GDTCORStoredEvent *_Nonnull event, BOOL *_Nonnull stop) {
    return [GDTCCTQosTierFromGDTCOREventQosTier(event.qosTier) isEqual:@(GDTCCTQoSDefault)];
  }];
}

/** Returns a set of logs that are ok to upload whilst on wifi.
 *
 * @note This should be called from a thread safe method.
 * @return A set of logs that are ok to upload whilst on wifi.
 */
- (NSSet<GDTCORStoredEvent *> *)logEventsOkToSendOnWifi:(NSSet<GDTCORStoredEvent *> *)events {
  return [events objectsPassingTest:^BOOL(GDTCORStoredEvent *_Nonnull event, BOOL *_Nonnull stop) {
    NSNumber *qosTier = GDTCCTQosTierFromGDTCOREventQosTier(event.qosTier);
    return [qosTier isEqual:@(GDTCCTQoSDefault)] || [qosTier isEqual:@(GDTCCTQoSWifiOnly)] ||
           [qosTier isEqual:@(GDTCCTQoSDaily)];
  }];
}

/** Returns a set of logs that only should have a single upload attempt per day.
 *
 * @note This should be called from a thread safe method.
 * @return A set of logs that are ok to upload only once per day.
 */
- (NSSet<GDTCORStoredEvent *> *)logEventsOkToSendDaily:(NSSet<GDTCORStoredEvent *> *)events {
  return [events objectsPassingTest:^BOOL(GDTCORStoredEvent *_Nonnull event, BOOL *_Nonnull stop) {
    return [GDTCCTQosTierFromGDTCOREventQosTier(event.qosTier) isEqual:@(GDTCCTQoSDaily)];
  }];
}

#pragma mark - GDTCORUploadPackageProtocol

- (void)packageDelivered:(GDTCORUploadPackage *)package successful:(BOOL)successful {
  dispatch_async(_queue, ^{
    NSSet<GDTCORStoredEvent *> *events = [package.events copy];
    for (GDTCORStoredEvent *event in events) {
      // We don't know what collection the event was contained in, so attempt removal from all.
      [self.CCTEvents removeObject:event];
      [self.FLLEvents removeObject:event];
      [self.CSHEvents removeObject:event];
    }
  });
}

- (void)packageExpired:(GDTCORUploadPackage *)package {
  [self packageDelivered:package successful:YES];
}

@end
