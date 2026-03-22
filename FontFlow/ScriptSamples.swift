//
//  ScriptSamples.swift
//  FontFlow
//
//  Created on 2026/3/21.
//

import Foundation

struct ScriptSample {
    let name: String
    let sampleText: String
}

enum ScriptSamples {

    static let `default` = all[0] // Latin

    static let all: [ScriptSample] = [
        ScriptSample(
            name: "Latin",
            sampleText: "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs."
        ),
        ScriptSample(
            name: "Cyrillic",
            sampleText: "\u{0421}\u{044A}\u{0435}\u{0448}\u{044C} \u{0436}\u{0435} \u{0435}\u{0449}\u{0451} \u{044D}\u{0442}\u{0438}\u{0445} \u{043C}\u{044F}\u{0433}\u{043A}\u{0438}\u{0445} \u{0444}\u{0440}\u{0430}\u{043D}\u{0446}\u{0443}\u{0437}\u{0441}\u{043A}\u{0438}\u{0445} \u{0431}\u{0443}\u{043B}\u{043E}\u{043A} \u{0434}\u{0430} \u{0432}\u{044B}\u{043F}\u{0435}\u{0439} \u{0447}\u{0430}\u{044E}."
        ),
        ScriptSample(
            name: "Greek",
            sampleText: "\u{0393}\u{03B1}\u{03B6}\u{03AD}\u{03B5}\u{03C2} \u{03BA}\u{03B1}\u{1F76} \u{03BC}\u{03C5}\u{03C1}\u{03C4}\u{03B9}\u{1F72}\u{03C2} \u{03B4}\u{1F72}\u{03BD} \u{03B8}\u{1F70} \u{03B2}\u{03C1}\u{1FF6} \u{03C0}\u{03B9}\u{1F70} \u{03C3}\u{03C4}\u{1F78} \u{03C7}\u{03C1}\u{03C5}\u{03C3}\u{03B1}\u{03C6}\u{1F76} \u{03BE}\u{03AD}\u{03C6}\u{03C9}\u{03C4}\u{03BF}."
        ),
        ScriptSample(
            name: "Arabic",
            sampleText: "\u{0635}\u{0650}\u{0641} \u{062E}\u{064E}\u{0644}\u{0642}\u{064E} \u{062E}\u{064E}\u{0644}\u{0642}\u{064D} \u{0643}\u{064E}\u{0630}\u{0650}\u{0628}\u{064E} \u{0637}\u{064E}\u{0638}\u{064E} \u{0641}\u{064E}\u{0639}\u{064E}\u{0633}\u{064E}\u{0642}\u{064E}\u{0641} \u{0642}\u{0650}\u{0637}\u{0639}\u{064E}\u{0629}\u{064E} \u{0643}\u{064E}\u{0623}\u{064E}\u{062E}\u{064E}\u{0636}\u{064E}\u{0631} \u{062B}\u{064E}\u{0648}\u{0628} \u{062C}\u{064F}\u{0631}\u{062D}\u{064D}."
        ),
        ScriptSample(
            name: "Hebrew",
            sampleText: "\u{05D3}\u{05D2} \u{05E1}\u{05E7}\u{05E8}\u{05DF} \u{05E9}\u{05D8} \u{05D1}\u{05D9}\u{05DD} \u{05DE}\u{05D0}\u{05D5}\u{05DB}\u{05D6}\u{05D1} \u{05D5}\u{05DC}\u{05E4}\u{05EA}\u{05E2} \u{05DE}\u{05E6}\u{05D0} \u{05DC}\u{05D5} \u{05D7}\u{05D1}\u{05E8}\u{05D4} \u{05D0}\u{05D9}\u{05DA} \u{05D4}\u{05E7}\u{05DC}\u{05D9}\u{05D8}\u{05D4}."
        ),
        ScriptSample(
            name: "Devanagari",
            sampleText: "\u{0910}\u{0938}\u{0947}\u{091A}\u{094D}\u{091B} \u{0905}\u{0928}\u{094D}\u{092F} \u{092D}\u{093E}\u{0937}\u{093E}\u{0913}\u{0902} \u{0915}\u{0940} \u{0924}\u{0930}\u{0939} \u{0939}\u{093F}\u{0928}\u{094D}\u{0926}\u{0940} \u{092C}\u{093E}\u{092F}\u{0947}\u{0902} \u{0938}\u{0947} \u{0926}\u{093E}\u{092F}\u{0947}\u{0902} \u{0914}\u{0930} \u{0938}\u{094D}\u{0935}\u{0924}\u{0928}\u{094D}\u{0924}\u{094D}\u{0930} \u{0930}\u{0942}\u{092A} \u{0938}\u{0947} \u{0932}\u{093F}\u{0916}\u{0940} \u{091C}\u{093E} \u{0938}\u{0915}\u{0924}\u{0940} \u{0939}\u{0948}\u{0964}"
        ),
        ScriptSample(
            name: "Chinese",
            sampleText: "\u{5929}\u{5730}\u{7384}\u{9EC4}\u{FF0C}\u{5B87}\u{5B99}\u{6D2A}\u{8352}\u{3002}\u{65E5}\u{6708}\u{76C8}\u{6603}\u{FF0C}\u{8FB0}\u{5BBF}\u{5217}\u{5F20}\u{3002}\u{5BD2}\u{6765}\u{6691}\u{5F80}\u{FF0C}\u{79CB}\u{6536}\u{51AC}\u{85CF}\u{3002}"
        ),
        ScriptSample(
            name: "Japanese",
            sampleText: "\u{3044}\u{308D}\u{306F}\u{306B}\u{307B}\u{3078}\u{3068}\u{3061}\u{308A}\u{306C}\u{308B}\u{3092}\u{308F}\u{304B}\u{3088}\u{305F}\u{308C}\u{305D}\u{3064}\u{306D}\u{306A}\u{3089}\u{3080}\u{3046}\u{3090}\u{306E}\u{304A}\u{304F}\u{3084}\u{307E}\u{3051}\u{3075}\u{3053}\u{3048}\u{3066}\u{3042}\u{3055}\u{304D}\u{3086}\u{3081}\u{307F}\u{3057}\u{3091}\u{3072}\u{3082}\u{305B}\u{3059}"
        ),
        ScriptSample(
            name: "Korean",
            sampleText: "\u{D0A4}\u{C2A4}\u{C758} \u{ACE0}\u{C720}\u{C870}\u{AC74}\u{C740} \u{D55C}\u{AD6D}\u{C5B4}\u{C758} \u{ACE0}\u{C720}\u{C870}\u{AC74}\u{C774}\u{B2E4}. \u{D0A4}\u{C2A4}\u{C758} \u{ACE0}\u{C720}\u{C870}\u{AC74}\u{C740} \u{D55C}\u{AD6D}\u{C5B4}\u{C758} \u{ACE0}\u{C720}\u{C870}\u{AC74}\u{C774}\u{B2E4}."
        ),
        ScriptSample(
            name: "Thai",
            sampleText: "\u{0E40}\u{0E1B}\u{0E47}\u{0E19}\u{0E21}\u{0E19}\u{0E38}\u{0E29}\u{0E22}\u{0E4C}\u{0E2A}\u{0E38}\u{0E14}\u{0E1B}\u{0E23}\u{0E30}\u{0E40}\u{0E2A}\u{0E23}\u{0E34}\u{0E10}\u{0E40}\u{0E25}\u{0E34}\u{0E28}\u{0E04}\u{0E38}\u{0E13}\u{0E04}\u{0E48}\u{0E32} \u{0E01}\u{0E27}\u{0E48}\u{0E32}\u{0E1A}\u{0E23}\u{0E23}\u{0E14}\u{0E32}\u{0E1D}\u{0E39}\u{0E07}\u{0E2A}\u{0E31}\u{0E15}\u{0E27}\u{0E4C}\u{0E40}\u{0E14}\u{0E23}\u{0E31}\u{0E08}\u{0E09}\u{0E32}\u{0E19}"
        ),
    ]
}
