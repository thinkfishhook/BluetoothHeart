//
//  ViewController.m
//  Core Bluetooth
//
//  Created by Evan DeLaney on 10/17/14.
//  Copyright (c) 2014 Fish Hook LLC. All rights reserved.
//

@import CoreBluetooth;

#import "ViewController.h"

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *heartRateMonitor;
@property (weak, nonatomic) IBOutlet UILabel *manufacturerLabel;
@property (weak, nonatomic) IBOutlet UILabel *hardwareLabel;
@property (weak, nonatomic) IBOutlet UILabel *firmwareLabel;
@property (weak, nonatomic) IBOutlet UILabel *bpmLabel;
@property (weak, nonatomic) IBOutlet UILabel *batteryLabel;

@end

static NSString * const FHKHeartRateServiceID = @"180D";
static NSString * const FHKDeviceInfoServiceID = @"180A";
static NSString * const FHKBatteryServiceID = @"180F";

static NSString * const FHKBPMCharacteristicID = @"2A37";
static NSString * const FHKManufacturerCharacteristicID = @"2A29";
static NSString * const FHKHardwareRevCharacteristicID = @"2A27";
static NSString * const FHKFirmwareRevCharacteristicID = @"2A26";
static NSString * const FHKBatteryCharaceristicID = @"2A19";

@implementation ViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
}

#pragma mark - Central Manager Delegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"%ld", central.state);
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"%@\n\tperipheral: %@\n\tadvertisement data: %@\n\tRSSI: %@", central, peripheral, advertisementData, RSSI);
    
    if ([peripheral.name isEqualToString:@"TICKR RUN"]) {
        [central stopScan];
        self.heartRateMonitor = peripheral;
        [central connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@", error);
}

#pragma mark - Peripheral Delegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"service: %@", service);
        
        if ([service.UUID isEqual:[CBUUID UUIDWithString:FHKBatteryServiceID]] ||
            [service.UUID isEqual:[CBUUID UUIDWithString:FHKDeviceInfoServiceID]] ||
            [service.UUID isEqual:[CBUUID UUIDWithString:FHKHeartRateServiceID]]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"characteristic:%@" , characteristic);
        
        if (characteristic.properties & CBCharacteristicPropertyRead) {
            [peripheral readValueForCharacteristic:characteristic];
        }
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FHKManufacturerCharacteristicID]]) {
        NSString *string = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        self.manufacturerLabel.text = string;
    }
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FHKHardwareRevCharacteristicID]]) {
        NSString *string = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        self.hardwareLabel.text = string;
    }
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FHKFirmwareRevCharacteristicID]]) {
        NSString *string = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        self.firmwareLabel.text = string;
    }
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FHKBPMCharacteristicID]]){
        
        NSData *data = characteristic.value;
        const uint8_t *reportData = data.bytes;
        uint16_t bpm = 0;
        
        if ((reportData[0] & 0x01) == 0) {
            bpm = reportData[1];
        }
        else {
            bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));
        }
        
        self.bpmLabel.text = [NSString stringWithFormat:@"%hu", bpm];
    }
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FHKBatteryCharaceristicID]]) {
        UInt8 batteryLevel = ((UInt8*)characteristic.value.bytes)[0];
        self.batteryLabel.text = [NSString stringWithFormat:@"%hhu", batteryLevel];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@",
              [error localizedDescription]);
    }
}

@end
