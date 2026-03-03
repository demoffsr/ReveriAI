//
//  DreamReminderAttributesBundle.swift
//  DreamReminderAttributes
//
//  Created by Dmitry Demidov on 22.02.2026.
//

import WidgetKit
import SwiftUI

@main
struct DreamReminderAttributesBundle: WidgetBundle {
    var body: some Widget {
        DreamReminderAttributes()
        DreamReminderAttributesControl()
        DreamReminderAttributesLiveActivity()
    }
}
