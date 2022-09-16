//
//  PaymentSheetFormFactory+Card.swift
//  StripeiOS
//
//  Created by Yuki Tokuhiro on 3/22/22.
//  Copyright © 2022 Stripe, Inc. All rights reserved.
//

import Foundation
import UIKit
@_spi(STP) import StripeUICore
@_spi(STP) import StripeCore

extension PaymentSheetFormFactory {
    func makeCard(theme: ElementsUITheme = .default) -> PaymentMethodElement {
        let isLinkEnabled = offerSaveToLinkWhenSupported && canSaveToLink
        
        var cardElement: [Element?] = [
            CardSection(theme: theme),
            makeBillingAddressSection(
                collectionMode: .countryAndPostal(countriesRequiringPostalCollection: ["US", "GB", "CA"]),
                countries: nil
            )
        ]
        
        if saveMode == .userSelectable && !canSaveToLink {
            cardElement.append(makeSaveCheckbox(
                label: String.Localized.save_this_card_for_future_$merchant_payments(
                    merchantDisplayName: configuration.merchantDisplayName
                )
            ))
        }
        
        if isLinkEnabled {
            return LinkEnabledPaymentMethodElement(
                type: .card,
                paymentMethodElement: FormElement(elements: cardElement, theme: theme),
                configuration: configuration,
                linkAccount: linkAccount,
                country: intent.countryCode
            )
        } else {
            if configuration.forceRequireEmail {
                cardElement.insert(SectionElement(makeEmail(), theme: theme), at: 0)
            }
            return FormElement(elements: cardElement, theme: theme)
        }
    }
}
