import Foundation

extension Dream {
    static var preview: [Dream] {
        let calendar = Calendar.current

        let dream1 = Dream(
            text: "I was walking through a quiet city at night, but everything felt soft and unreal, like it was made of light instead of buildings. The streets kept changing every time I turned around.",
            title: "City of Light",
            emotions: [.joyful, .calm],
            createdAt: calendar.date(byAdding: .hour, value: -2, to: .now)!
        )

        let dream2 = Dream(
            text: "There was a garden full of flowers that sang when you touched them. I was dancing with someone I couldn't see clearly, but it felt warm and safe.",
            title: "Singing Garden",
            emotions: [.inLove],
            createdAt: calendar.date(byAdding: .hour, value: -5, to: .now)!
        )

        let dream3 = Dream(
            text: "I was sitting by a lake, perfectly still. The water reflected a sky I'd never seen — two moons, purple clouds. I didn't want to leave.",
            title: "Two Moons Lake",
            emotions: [.calm],
            createdAt: calendar.date(byAdding: .day, value: -1, to: .now)!
        )

        let dream4 = Dream(
            text: "I was in a library where the books kept rearranging themselves. Every time I reached for one, it moved to a different shelf. The librarian spoke a language I almost understood.",
            title: "The Moving Library",
            emotions: [.confused, .anxious],
            createdAt: calendar.date(byAdding: .day, value: -2, to: .now)!
        )

        let dream5 = Dream(
            text: "I was taking an exam in a room that kept shrinking. The questions were in a language I couldn't read, and everyone else seemed to be finishing.",
            title: "The Shrinking Exam",
            emotions: [.anxious, .scared],
            createdAt: calendar.date(byAdding: .day, value: -3, to: .now)!
        )

        let dream6 = Dream(
            text: "Something was chasing me through a dark forest. I could hear it breathing but never saw what it was. The trees were closing in around me.",
            title: "Dark Forest Chase",
            emotions: [.scared],
            createdAt: calendar.date(byAdding: .day, value: -5, to: .now)!,
            isTranslated: true
        )

        let dream7 = Dream(
            text: "I was arguing with someone who kept changing faces. Every time I made a point, they became someone else entirely. I woke up frustrated.",
            title: "Changing Faces",
            emotions: [.angry, .confused],
            createdAt: calendar.date(byAdding: .day, value: -7, to: .now)!
        )

        return [dream1, dream2, dream3, dream4, dream5, dream6, dream7]
    }
}
