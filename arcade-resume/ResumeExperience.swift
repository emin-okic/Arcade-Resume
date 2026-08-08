import Foundation

struct ResumeExperience: Identifiable, Equatable {
    let id: String
    let title: String
    let organization: String
    let location: String
    let period: String
    let summary: String
    let responsibilities: [String]
    let skills: [String]

    static let all: [ResumeExperience] = [
        ResumeExperience(
            id: "freelance",
            title: "Freelance Software Engineer",
            organization: "Self Employed",
            location: "Johnston, IA",
            period: "Aug 2023 - Jan 2025",
            summary: "$50,000+ in client revenue across SaaS, CRM, and customer-facing platforms.",
            responsibilities: [
                "Coordinated software database development for 10+ clients.",
                "Delivered revenue-generating CRM systems for 5+ clients.",
                "Designed a customer-facing digital platform supporting high user volume.",
                "Wrote reports from data collection and analysis findings."
            ],
            skills: ["SaaS", "CRM", "Databases", "Data Analysis"]
        ),
        ResumeExperience(
            id: "honest-game",
            title: "Lead Software Engineer",
            organization: "Honest Game",
            location: "Chicago, IL",
            period: "Nov 2022 - Aug 2023",
            summary: "Scaled backend systems and translated regulatory rules into faster product workflows.",
            responsibilities: [
                "Re-architected backend infrastructure to support 200,000+ daily users.",
                "Optimized database queries and backend workflows with Python and SQL.",
                "Improved processing speed by 30% by turning compliance rules into backend logic."
            ],
            skills: ["Python", "SQL", "Backend", "Compliance"]
        ),
        ResumeExperience(
            id: "maven-wave",
            title: "Software Engineer",
            organization: "Maven Wave Partners",
            location: "Chicago, IL",
            period: "Jun 2021 - Aug 2022",
            summary: "Built cloud-backed risk systems and improved stakeholder-facing product accuracy.",
            responsibilities: [
                "Built an insurance risk analysis engine for In-N-Out with JavaScript, Python, and SQL.",
                "Deployed GCP infrastructure with Terraform to streamline cloud operations.",
                "Partnered with stakeholders to improve new-product risk assessment accuracy by 75%."
            ],
            skills: ["JavaScript", "Python", "SQL", "GCP", "Terraform"]
        ),
        ResumeExperience(
            id: "ames-lab",
            title: "Software Scientist",
            organization: "Ames National Laboratory",
            location: "Ames, IA",
            period: "Sep 2020 - May 2021",
            summary: "Created systems and algorithms for scientific computing and energy research.",
            responsibilities: [
                "Developed C build-system tools to accelerate energy research simulations.",
                "Built scalable algorithms to improve large dataset accuracy and performance.",
                "Collaborated with scientists to translate research needs into software."
            ],
            skills: ["C", "Algorithms", "Research", "Large Datasets"]
        ),
        ResumeExperience(
            id: "cambridge",
            title: "Intern Data Engineer",
            organization: "Cambridge Investment Research",
            location: "Fairfield, IA",
            period: "May 2020 - Aug 2020",
            summary: "Designed data workflows and services for financial reporting and CRM access.",
            responsibilities: [
                "Designed and maintained data integration workflows for accurate reporting.",
                "Developed APIs and data services to streamline CRM workflows and data access.",
                "Designed a C# and .NET database vault to secure financial records."
            ],
            skills: ["C#", ".NET", "APIs", "Data Engineering"]
        )
    ]
}
