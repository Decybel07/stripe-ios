//
//  AddressSectionElement.swift
//  StripeUICore
//
//  Created by Mel Ludowise on 10/5/21.
//  Copyright © 2021 Stripe, Inc. All rights reserved.
//

import Foundation
@_spi(STP) import StripeCore

/**
 A section that contains a country dropdown and the country-specific address fields
 */
@_spi(STP) public class AddressSectionElement: SectionElement {
    /// Describes an address to use as a default for AddressSectionElement
    public struct Defaults {
        @_spi(STP) public static let empty = Defaults()
        var name: String?

        /// City, district, suburb, town, or village.
        var city: String?

        /// Two-letter country code (ISO 3166-1 alpha-2).
        var country: String?

        /// Address line 1 (e.g., street, PO Box, or company name).
        var line1: String?

        /// Address line 2 (e.g., apartment, suite, unit, or building).
        var line2: String?

        /// ZIP or postal code.
        var postalCode: String?

        /// State, county, province, or region.
        var state: String?

        /// Initializes an Address
        public init(city: String? = nil, country: String? = nil, line1: String? = nil, line2: String? = nil, postalCode: String? = nil, state: String? = nil) {
            self.city = city
            self.country = country
            self.line1 = line1
            self.line2 = line2
            self.postalCode = postalCode
            self.state = state
        }
    }
    /// Describes which address fields to collect
    public enum CollectionMode {
        case all
        /// Collects country and postal code if the country is one of `countriesRequiringPostalCollection`
        /// - Note: Really only useful for cards, where we only collect postal for a handful of countries
        case countryAndPostal(countriesRequiringPostalCollection: [String])
    }
    /// Fields that this section can collect in addition to the address
    public struct AdditionalFields: OptionSet {
        public let rawValue: Int
        static let name = AdditionalFields(rawValue: 1 << 0)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    // MARK: - Elements
    public let name: TextFieldElement?
    public let country: DropdownFieldElement
    public private(set) var line1: TextFieldElement?
    public private(set) var line2: TextFieldElement?
    public private(set) var city: TextFieldElement?
    public private(set) var state: TextFieldElement?
    public private(set) var postalCode: TextFieldElement?
    
    public let collectionMode: CollectionMode
    public var selectedCountryCode: String {
        return countryCodes[country.selectedIndex]
    }
    public var isValidAddress: Bool {
        return elements
            .compactMap { $0 as? TextFieldElement }
            .reduce(true) { isValid, element in
                if case .valid = element.validationState {
                    return isValid
                }
                return false
            }
    }
    let countryCodes: [String]

    /**
     Creates an address section with a country dropdown populated from the given list of countryCodes.

     - Parameters:
       - title: The title for this section
       - countries: List of region codes to display in the country picker dropdown. If nil, the list of countries from `addressSpecProvider` is used instead.
       - locale: Locale used to generate the display names for each country
       - addressSpecProvider: Determines the list of address fields to display for a selected country
       - defaults: Default address to prepopulate address fields with
     */
    public init(
        title: String? = nil,
        countries: [String]? = nil,
        locale: Locale = .current,
        addressSpecProvider optionalAddressSpecProvider: AddressSpecProvider? = nil,
        defaults optionalDefaults: Defaults? = nil,
        collectionMode: CollectionMode = .all,
        additionalFields: AdditionalFields = []
    ) {
        // TODO: After switching to Xcode 12.5 (which fixed @_spi default initailizers)
        // we can make these into default initializers instead of optionals.
        let addressSpecProvider: AddressSpecProvider = optionalAddressSpecProvider ?? .shared
        let defaults: Defaults = optionalDefaults ?? .empty

        let dropdownCountries: [String]
        if let countries = countries {
            assert(!countries.isEmpty, "`countries` must contain at least one country")
            dropdownCountries = countries
        } else {
            assert(!addressSpecProvider.countries.isEmpty, "`addressSpecProvider` must contain at least one country")
            dropdownCountries = addressSpecProvider.countries
        }

        self.collectionMode = collectionMode
        self.countryCodes = locale.sortedByTheirLocalizedNames(dropdownCountries)
        
        // Initialize field Elements
        self.name = additionalFields.contains(.name) ? TextFieldElement.Address.makeName(defaultValue: defaults.name) : nil
        self.country = DropdownFieldElement.Address.makeCountry(
            label: String.Localized.country_or_region,
            countryCodes: countryCodes,
            defaultCountry: defaults.country,
            locale: locale
        )
        
        super.init(
            title: title,
            elements: []
        )
        self.updateAddressFields(
            for: countryCodes[country.selectedIndex],
            addressSpecProvider: addressSpecProvider,
            defaults: defaults
        )
        country.didUpdate = { [weak self] index in
            guard let self = self else { return }
            self.updateAddressFields(
                for: self.countryCodes[index],
                addressSpecProvider: addressSpecProvider
            )
        }
    }

    /// - Parameter defaults: Populates the new fields with the provided defaults, or the current fields' text if `nil`.
    private func updateAddressFields(
        for countryCode: String,
        addressSpecProvider: AddressSpecProvider,
        defaults: Defaults? = nil
    ) {
        // Create the new address fields' default text
        let defaults = defaults ?? Defaults(
            city: city?.text,
            country: nil,
            line1: line1?.text,
            line2: line2?.text,
            postalCode: postalCode?.text,
            state: state?.text
        )
        
        // Get the address spec for the country and filter out unused fields
        let spec = addressSpecProvider.addressSpec(for: countryCode)
        let fieldOrdering = spec.fieldOrdering.filter {
            switch collectionMode {
            case .all:
                return true
            case .countryAndPostal(let countriesRequiringPostalCollection):
                if case .postal = $0 {
                    return countriesRequiringPostalCollection.contains(countryCode)
                } else {
                   return false
                }
            }
        }
        // Re-create the address fields
        line1 = fieldOrdering.contains(.line) ?
            TextFieldElement.Address.makeLine1(defaultValue: defaults.line1) : nil
        line2 = fieldOrdering.contains(.line) ?
            TextFieldElement.Address.makeLine2(defaultValue: defaults.line2) : nil
        city = fieldOrdering.contains(.city) ?
            spec.makeCityElement(defaultValue: defaults.city) : nil
        state = fieldOrdering.contains(.state) ?
            spec.makeStateElement(defaultValue: defaults.state) : nil
        postalCode = fieldOrdering.contains(.postal) ?
            spec.makePostalElement(countryCode: countryCode, defaultValue: defaults.postalCode) : nil
        
        // Order the address fields according to `fieldOrdering`
        let addressFields: [TextFieldElement?] = fieldOrdering.reduce([]) { partialResult, fieldType in
            // This should be a flatMap but I'm having trouble satisfying the compiler
            switch fieldType {
            case .line:
                return partialResult + [line1, line2]
            case .city:
                return partialResult + [city]
            case .state:
                return partialResult + [state]
            case .postal:
                return partialResult + [postalCode]
            }
        }
        // Set the new address fields, including any additional fields
        elements = [name].compactMap { $0 } + [country] + addressFields.compactMap { $0 }
    }
}
