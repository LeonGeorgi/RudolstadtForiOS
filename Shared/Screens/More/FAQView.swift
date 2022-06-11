//
//  FAQView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct FAQView: View {
    var body: some View {
        List {
            FAQCell(question: "faq.schedule.question", answer: "faq.schedule.answer")
            FAQCell(question: "faq.suggestions.question", answer: "faq.suggestions.answer")
            FAQCell(question: "faq.rating.question", answer: "faq.rating.answer")
        }.navigationTitle("faq.title")
    }
}

struct FAQCell: View {
    let question: LocalizedStringKey
    let answer: LocalizedStringKey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question)
                .font(.headline)
            Text(answer)
        }.padding(.vertical, 10)

    }
}

struct FAQView_Previews: PreviewProvider {
    static var previews: some View {
        FAQView()
    }
}
