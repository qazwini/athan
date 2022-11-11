//
//  PrayerTimes.swift
//  Adhan
//
//  Copyright © 2018 Batoul Apps. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/**
  Prayer times for a location and date using the given calculation parameters.

  All prayer times are in UTC and should be displayed using a DateFormatter that
  has the correct timezone set.
 */
public class PrayerTimes {
    public var timeMap: [Prayer: Date]
    
    private let prayers: [Prayer]
    private let coordinates: Coordinates
    private let date: Date
    private let calculationParameters: CalculationParameters

    public init?(
        prayers: [Prayer],
        coordinates: Coordinates,
        date: Date,
        calculationParameters: CalculationParameters,
        calculateMidnight: Bool = true
    ) {
        self.prayers = prayers
        self.coordinates = coordinates
        self.date = date
        self.calculationParameters = calculationParameters
        self.timeMap = [Prayer: Date]()
        
        let cal = Calendar.gregorianUTC
        let dateComp = cal.dateComponents([.year, .month, .day], from: date)

        guard let year = dateComp.year,
              let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) else { return nil }
        
        let tomorrow = date.dayAfter
        let tomorrowDateComp = cal.dateComponents([.year, .month, .day], from: tomorrow)

        guard let solarTime = SolarTime(date: dateComp, coordinates: coordinates),
              let tomorrowSolarTime = SolarTime(date: tomorrowDateComp, coordinates: coordinates),
              let sunriseDate = cal.date(from: solarTime.sunrise),
              let sunsetDate = cal.date(from: solarTime.sunset),
              let tomorrowSunrise = cal.date(from: tomorrowSolarTime.sunrise) else {
                // unable to determine transit, sunrise or sunset aborting calculations
                return nil
        }
        
        var tempMap = [Prayer: Date]()

        tempMap[.sunrise] = cal.date(from: solarTime.sunrise)
        tempMap[.sunset] = cal.date(from: solarTime.sunset)
        tempMap[.maghrib] = cal.date(from: solarTime.sunset)
        tempMap[.dhuhr] = cal.date(from: solarTime.transit)

        if let asrComponents = solarTime.afternoon(shadowLength: calculationParameters.madhab.shadowLength) {
            tempMap[.asr] = cal.date(from: asrComponents)
        }

        // get night length
        let night = tomorrowSunrise.timeIntervalSince(sunsetDate)

        if let fajrComponents = solarTime.timeForSolarAngle(Angle(-calculationParameters.fajrAngle), afterTransit: false) {
            tempMap[.fajr] = cal.date(from: fajrComponents)
        }

        // special case for moonsighting committee above latitude 55
        if calculationParameters.method == .moonsightingCommittee && coordinates.latitude >= 55 {
            let nightFraction = night / 7
            tempMap[.fajr] = sunriseDate.addingTimeInterval(-nightFraction)
        }

        let safeFajr: Date = {
            guard calculationParameters.method != .moonsightingCommittee else {
                return Astronomical.seasonAdjustedMorningTwilight(latitude: coordinates.latitude, day: dayOfYear, year: year, sunrise: sunriseDate)
            }

            let portion = calculationParameters.nightPortions(using: coordinates).fajr
            let nightFraction = portion * night

            return sunriseDate.addingTimeInterval(-nightFraction)
        }()

        if !tempMap.keys.contains(.fajr) || tempMap[.fajr]?.compare(safeFajr) == .orderedAscending {
            tempMap[.fajr] = safeFajr
        }

        // Isha calculation with check against safe value
        if calculationParameters.ishaInterval > 0 {
            if let maghribTime = tempMap[.maghrib] {
                tempMap[.isha] = maghribTime.addingTimeInterval(calculationParameters.ishaInterval.timeInterval)
            }
        } else {
            if let ishaComponents = solarTime.timeForSolarAngle(Angle(-calculationParameters.ishaAngle), afterTransit: true) {
                tempMap[.isha] = cal.date(from: ishaComponents)
            }

            // special case for moonsighting committee above latitude 55
            if calculationParameters.method == .moonsightingCommittee && coordinates.latitude >= 55 {
                let nightFraction = night / 7
                tempMap[.isha] = sunsetDate.addingTimeInterval(nightFraction)
            }

            let safeIsha: Date = {
                guard calculationParameters.method != .moonsightingCommittee else {
                    return Astronomical.seasonAdjustedEveningTwilight(latitude: coordinates.latitude, day: dayOfYear, year: year, sunset: sunsetDate, shafaq: calculationParameters.shafaq)
                }

                let portion = calculationParameters.nightPortions(using: coordinates).isha
                let nightFraction = portion * night

                return sunsetDate.addingTimeInterval(nightFraction)
            }()

            if !tempMap.keys.contains(.isha) || tempMap[.isha]?.compare(safeIsha) == .orderedDescending {
                tempMap[.isha] = safeIsha
            }
        }
        
        // Maghrib calculation with check against safe value
        if let maghribAngle = calculationParameters.maghribAngle,
           let maghribComponents = solarTime.timeForSolarAngle(Angle(-maghribAngle), afterTransit: true),
           let maghribDate = cal.date(from: maghribComponents),
           // maghrib is considered safe if it falls between sunset and isha
           sunsetDate < maghribDate, (!tempMap.keys.contains(.isha) || tempMap[.isha]?.compare(maghribDate) == .orderedDescending) {
            tempMap[.maghrib] = maghribDate
        }
        
        // Midnight and 2/3 night calculation
        if calculateMidnight,
           let tomorrowPrayerTimes = PrayerTimes(
            prayers: prayers,
            coordinates: coordinates,
            date: tomorrow,
            calculationParameters: calculationParameters,
            calculateMidnight: false
           ),
           let todayMaghrib = tempMap[.maghrib],
           let tomorrowFajr = tomorrowPrayerTimes.timeMap[.fajr] {
            let nightDuration = tomorrowFajr.timeIntervalSince(todayMaghrib)
            tempMap[.midnight] = todayMaghrib.addingTimeInterval(nightDuration / 2).roundedMinute()
            tempMap[.twoThirdNight] = todayMaghrib.addingTimeInterval(nightDuration * (2 / 3)).roundedMinute()
        }
        
        for (prayer, time) in tempMap {
            self.timeMap[prayer] = time
                .addingTimeInterval(calculationParameters.adjustments.fromPrayer(prayer).timeInterval)
                .addingTimeInterval(calculationParameters.methodAdjustments.fromPrayer(prayer).timeInterval)
                .roundedMinute(rounding: calculationParameters.rounding)
        }
    }
    
    public func prayerTimes() -> [PrayerTime?] {
        return prayers.map {
            if let time = timeMap[$0] {
                return PrayerTime(prayer: $0, date: time)
            }
            return nil
        }
    }

    public func nextPrayer() -> PrayerTime? {
        guard let yesterdayTimes = PrayerTimes(prayers: prayers, coordinates: coordinates, date: date.dayBefore, calculationParameters: calculationParameters),
              let tomorrowTimes = PrayerTimes(prayers: prayers, coordinates: coordinates, date: date.dayAfter, calculationParameters: calculationParameters) else {
            return nil
        }
        let prayerTimeses = [yesterdayTimes, self, tomorrowTimes]
        
        for prayerTimes in prayerTimeses {
            for prayer in prayers {
                if let prayerDate = prayerTimes.timeMap[prayer], prayerDate > date {
                    return PrayerTime(prayer: prayer, date: prayerDate)
                }
            }
        }

        return nil
    }
}
