//
//  PrayerTime.swift
//  Adhan
//
//  Created by Mahdi Qazwini on 11/11/22.
//  Copyright © 2022 Batoul Apps. All rights reserved.
//

import Foundation

public struct PrayerTime {
    public let prayer: Prayer
    public let date: Date
    
    init(prayer: Prayer, date: Date) {
        self.prayer = prayer
        self.date = date
    }
}
