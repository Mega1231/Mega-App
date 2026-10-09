// The five onboarding letters (stage 2), from Becky's documents. One source
// for both the applicant page (as blocks) and the signed PDFs.
//
// Block types: h (section heading), p (paragraph), pb (bold paragraph),
// li (bullet), kv (bold label + value), quote (highlighted example),
// note (centred, emphasised), link.
const path = require("path");
const PDFDocument = require("pdfkit");

const AGENCY = {
  name: "Mega Homecare Inc",
  address: ["Head office: 200 Glendale Avenue North,", "Hamilton ON,", "Canada L8L 7K3"],
  email: "info@megahomecareinc.com",
  phone: "888-811-3429",
};

const DEFAULT_POSITION = "Caregiver";

/** Editable per caregiver when Becky sends the letters. */
const DEFAULT_JOB_DESCRIPTION =
  "Help the client with their daily living tasks, such as range-of-motion " +
  "exercises, bathing, and getting dressed and undressed. Arranging and " +
  "preparing nutritious meals, going with the client to appointments, and " +
  "doing regular light housework such as laundry and cleaning.";

const LETTER_IDS = ["offer", "welcome", "phone_policy", "shift_report", "communication"];

const trim = (v) => (typeof v === "string" ? v.trim() : "");

/** Normalises Becky's fields and lists what's missing. */
function normalizeFields(input) {
  const fields = {
    fullName: trim(input?.fullName),
    position: trim(input?.position) || DEFAULT_POSITION,
    payRate: trim(input?.payRate),
    schedule: trim(input?.schedule),
    startDate: trim(input?.startDate),
    jobDescription: trim(input?.jobDescription) || DEFAULT_JOB_DESCRIPTION,
  };
  const missing = [];
  if (!fields.fullName) missing.push("Full name");
  if (!fields.payRate) missing.push("Pay rate");
  if (!fields.schedule) missing.push("Schedule");
  if (!fields.startDate) missing.push("Start date");
  return { fields, missing };
}

function buildLetters(f) {
  const name = f.fullName;
  return [
    {
      id: "offer",
      title: "Offer Letter",
      heading: "Re: Offer of Employment",
      blocks: [
        { t: "p", text: `Dear ${name},` },
        { t: "p", text: "I am very pleased to offer you employment at MEGA HOMECARE INC conditional upon the acceptance of this offer letter and signing the description of duties for this position." },
        { t: "kv", label: "Position Title:", value: f.position },
        { t: "kv", label: "Pay Rate:", value: f.payRate },
        { t: "kv", label: "Schedule:", value: f.schedule },
        { t: "h", text: "Employment Terms and Conditions" },
        { t: "kv", label: "The effective date of your hire is", value: f.startDate },
        { t: "p", text: "Orientation is essential for all new employees. Your hiring manager will provide you with information for the next appropriate orientation session. If you have additional questions or concerns regarding Orientation requirements, please contact your manager." },
        { t: "p", text: "Required Documentation prior to your first job assignment:" },
        { t: "li", text: "2 pieces of ID" },
        { t: "li", text: "Personal Support Worker Certificate (if applicable)" },
        { t: "li", text: "Driver's License and abstract (obtained online through Service Ontario for $12, if applicable)" },
        { t: "li", text: "Copy of CPR & First Aid certificate (within the first 3 months of employment)" },
        { t: "li", text: "Criminal Records Check – A satisfactory Criminal Record Check and Vulnerable Sector Search is required in compliance with the Criminal Record Check procedure. This can be obtained from your local police department. A receipt to confirm proof of purchase is acceptable if the results are not available by your orientation day." },
        { t: "li", text: "Evidence of Registration – All regulated professions must provide evidence to your manager of current licensure with the approved Canadian College under the following conditions: A) All professions legislated under the Health Professions Act; B) All professions legislated under other Ontario government acts or college requirements. Any misrepresentation or falsification may be considered grounds for dismissal (if applicable)." },
        { t: "h", text: "Duration of Contract" },
        { t: "p", text: "It is understood that wages for these services are dependent on your providing services to a customer of the company. This is determined by matching you and your skill set with the needs and service requirements of one of our customers. As an employee of the company there may be times when a customer match is not possible and during those times there is no remuneration or wages being paid. You will still be considered an employee and therefore will be offered a customer match as soon as they become available." },
        { t: "h", text: "Job Description" },
        { t: "p", text: `${f.jobDescription} The duties and tasks are as outlined in the job title/description and by signing the job description, you agree that you are competent and capable of performing the duties assigned.` },
        { t: "h", text: "Confidentiality" },
        { t: "p", text: "You will agree to keep all of the company business and/or personal information strictly confidential at all times during the term of your employment and following your employment. Any personal, financial or professional information regarding any clients, contractors, subcontractors, employees or any other persons connected with the company shall also be held in the strictest confidence and shall not be discussed or disclosed to any persons whatsoever at any time or at any place. It is further agreed that you will not make any unauthorized copies of any business or other documentation or information without the prior consent of the company or remove any business equipment or documents or information, physically or electronically from the office. Failure to comply with confidentiality may lead to immediate termination of this employment contract." },
        { t: "h", text: "Sick Leave / Statutory Holidays" },
        { t: "p", text: "All sick leaves shall be taken without pay. If it is necessary to work on a statutory holiday at the request of the Employer, the hourly rate will be at 1½ times the basic rate of pay." },
        { t: "h", text: "Notice of Resignation" },
        { t: "p", text: "Should you wish to resign and voluntarily leave your employment, you agree to provide at least two weeks' notice of your intention to do so." },
        { t: "h", text: "Notice of Termination of Employment" },
        { t: "p", text: "During the probationary period, you may be terminated for unsuitability in the position for any reason without notice and without pay in lieu of notice. Following the probationary period of employment, the company will provide written notice in the event the employment relationship is severed, with or without reasons and with remuneration in lieu thereof in the amount of one week service. This notice shall be provided at least one week in advance, with the exception of egregious behavior, theft, insubordination, dishonesty on your resume, including qualifications, work permit or some other action that requires immediate dismissal which shall be without notice and without remuneration." },
        { t: "pb", text: `I, ${name}, hereby accept employment with the company, as a ${f.position}, on the terms and conditions stated above and I have read, understand and accept all the terms and conditions stipulated in the present agreement/contract and the attached Job Description. I declare the information given in my resume to be true and understand that any misrepresentation of facts may be considered grounds for dismissal.` },
      ],
    },
    {
      id: "welcome",
      title: "Welcome Letter",
      heading: "Welcome Letter",
      blocks: [
        { t: "p", text: `Dear ${name},` },
        { t: "p", text: "Welcome to the team!" },
        { t: "p", text: "Below you will find some very important information related to your position with MEGA HOMECARE INC." },
        { t: "h", text: "Schedule" },
        { t: "p", text: "You can log in to see your schedule in the Mega Homecare Inc app." },
        { t: "h", text: "Uniform" },
        { t: "p", text: "The expectation for dress code while on shift is SCRUBS." },
        { t: "h", text: "Contact Numbers" },
        { t: "pb", text: `Office hours are 9:00am – 5:00pm. The main office number is ${AGENCY.phone}.` },
        { t: "h", text: "Vacation" },
        { t: "p", text: "To book any time off from your scheduled shifts, you must submit your request two weeks before your requested time off so we can ensure continuity of care for our clients." },
        { t: "note", text: "Christmas/Winter Holiday requests must be submitted by November 1st." },
        { t: "note", text: "Summer Vacation requests are to be submitted by May 1st." },
        { t: "h", text: "Resources" },
        { t: "p", text: "This is the link to the Mandatory Awareness Training from the Ministry of Labour. Please print and send your certificate." },
        { t: "link", text: "http://www.labour.gov.on.ca/english/hs/elearn/worker/index.php" },
        { t: "p", text: "If you have any questions at all please let us know. We look forward to working together!" },
      ],
    },
    {
      id: "phone_policy",
      title: "Phone Usage Policy",
      heading: "Professional Phone Usage Policy",
      blocks: [
        { t: "p", text: `Dear ${name},` },
        { t: "p", text: "As we continue providing exceptional care to our clients, we would like to remind all staff of the importance of maintaining professional phone usage during shifts. Our primary focus is ensuring clients receive the highest standard of care, and minimizing distractions is essential in achieving this goal." },
        { t: "p", text: "Please review and adhere to the following guidelines regarding phone usage while on duty:" },
        { t: "li", text: "Personal laptops and more than one phone are not permitted during shifts." },
        { t: "li", text: "Personal phone calls should be limited to emergencies or essential matters only." },
        { t: "li", text: "Avoid extended conversations or activities unrelated to client care." },
        { t: "li", text: "Use discretion when using phones in the presence of clients to maintain a professional environment." },
        { t: "li", text: "Refrain from lengthy personal conversations, social media browsing, or other non-work-related phone usage during working hours." },
        { t: "p", text: "Please note that if a client raises two complaints regarding a caregiver's or PSW's phone usage, disciplinary action may be taken, up to and including termination of employment." },
        { t: "p", text: "We understand that urgent personal matters may occasionally arise, and we encourage open communication with management when necessary. We appreciate your cooperation and commitment to upholding the professionalism and dedication that define our agency." },
        { t: "p", text: "Thank you for your continued hard work and dedication." },
      ],
    },
    {
      id: "shift_report",
      title: "Shift Report Guidelines",
      heading: "Shift Report",
      blocks: [
        { t: "p", text: `Dear ${name},` },
        { t: "p", text: "This is a friendly reminder regarding the importance of completing detailed and accurate daily reports for each shift. Proper documentation is essential to ensure continuity of care, maintain professional standards, and support effective communication within our team." },
        { t: "pb", text: "Below is an example of a well-documented intake note:" },
        { t: "quote", text: "“During today's shift, I assisted the client with bathing and dressing. Breakfast consisting of oatmeal and fruit was served at 8:10 a.m. Medication assistance at 7:00 a.m., followed by completion of an exercise routine. Engaged in conversation with Mrs. Jane and played games together. Completed light housekeeping duties and disposed of garbage. The client used the toilet once. The client rested twice, at 10:00 a.m. and 12:00 p.m. No significant challenges were encountered.”" },
        { t: "p", text: "You may also include observations such as:" },
        { t: "li", text: "Client appeared in good spirits today and engaged well in activities." },
        { t: "li", text: "Noted improved appetite and willingness to participate in exercises." },
        { t: "li", text: "Client expressed satisfaction with the day's activities and companionship." },
        { t: "p", text: "Please note that completing a thorough report should take less than five minutes and is an important part of providing quality care." },
        { t: "p", text: "Thank you for your cooperation, professionalism, and continued dedication." },
      ],
    },
    {
      id: "communication",
      title: "Communication Compliance",
      heading: "Communication Compliance Policy",
      blocks: [
        { t: "p", text: `Dear ${name},` },
        { t: "p", text: "This policy is mandatory and applies to all employees. Employees are expected to maintain professional boundaries and use only agency-approved communication channels for work-related communication with families, clients, and coworkers." },
        { t: "pb", text: "Employees may not exchange, request, provide, or use personal phone numbers, personal email addresses, or personal social-media accounts for work-related communication. Employees must not circumvent the agency's communication system by using another person to relay messages or by communicating through an unauthorized channel." },
        { t: "p", text: "Any suspected or confirmed violation must be reported to management promptly. Violations may result in corrective or disciplinary action, up to and including termination of employment, consistent with agency policy and applicable law." },
        { t: "p", text: "Employees are responsible for reviewing and following this policy at all times. Failure to comply may be considered a serious breach of agency policy." },
        { t: "p", text: "Please click the link below to download the agency communication app. All required work-related communication must be conducted through the agency-approved platform." },
        { t: "link", text: "https://landing.megahomecareinc.com" },
        { t: "pb", text: `I, ${name}, by accessing and using the agency communication app, acknowledge my responsibility to comply with this policy.` },
      ],
    },
  ];
}

// ── PDF ──

const LOGO = path.join(__dirname, "assets", "logo.jpg");
const BLUE = "#1f4e9c";
const TEXT = "#1d2433";

function formatToronto(date, withTime) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Toronto",
    year: "numeric", month: "long", day: "numeric",
    ...(withTime ? { hour: "numeric", minute: "2-digit", timeZoneName: "short" } : {}),
  }).format(date);
}

/**
 * Renders a signed letter. [signature] is a PNG buffer; [signedAt] a Date;
 * [audit] is printed small under the signature (e.g. IP / device).
 */
function renderLetterPdf(letter, { name, signature, signedAt, audit = "" }) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: "LETTER",
      margins: { top: 54, bottom: 60, left: 64, right: 64 },
      info: { Title: `${letter.title} – ${name}`, Author: AGENCY.name },
    });
    const chunks = [];
    doc.on("data", (c) => chunks.push(c));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    const width = doc.page.width - doc.page.margins.left - doc.page.margins.right;
    const left = doc.page.margins.left;

    // Letterhead: agency details left, logo right.
    const top = doc.y;
    doc.image(LOGO, left + width - 120, top - 6, { width: 120 });
    doc.font("Helvetica-Bold").fontSize(11).fillColor(TEXT).text(AGENCY.name, left, top);
    for (const line of AGENCY.address) doc.text(line);
    doc.moveDown(0.4).font("Helvetica").fontSize(10)
      .text(`Email: ${AGENCY.email}`).text(`Contact #: ${AGENCY.phone}`);
    doc.moveDown(0.8).font("Helvetica-Bold").fontSize(11).text(name);
    doc.moveDown(1);

    doc.font("Helvetica-Bold").fontSize(13).fillColor(BLUE)
      .text(letter.heading, left, doc.y, { width, align: "center", underline: true });
    doc.moveDown(1).fillColor(TEXT);

    const para = { width, align: "justify", lineGap: 2 };
    const limit = () => doc.page.height - doc.page.margins.bottom;
    letter.blocks.forEach((b, i) => {
      // Keep a closing acknowledgement on the same page as the signature.
      if (i === letter.blocks.length - 1 && b.t === "pb") {
        doc.font("Helvetica-Bold").fontSize(10.5);
        if (doc.y + doc.heightOfString(b.text, para) + 120 > limit()) doc.addPage();
      }
      switch (b.t) {
        case "h":
          doc.moveDown(0.5).font("Helvetica-Bold").fontSize(11).text(b.text, left, doc.y, { width });
          doc.moveDown(0.25);
          break;
        case "pb":
          doc.font("Helvetica-Bold").fontSize(10.5).text(b.text, left, doc.y, para).moveDown(0.6);
          break;
        case "kv":
          doc.font("Helvetica-Bold").fontSize(10.5)
            .text(`${b.label} `, left, doc.y, { continued: true, width })
            .font("Helvetica").text(b.value || "—").moveDown(0.3);
          break;
        case "li":
          doc.font("Helvetica").fontSize(10.5)
            .text(`•  ${b.text}`, left + 12, doc.y, { width: width - 12, lineGap: 2 }).moveDown(0.3);
          break;
        case "quote":
          doc.font("Helvetica-Bold").fontSize(10.5).fillColor("#c62828")
            .text(b.text, left, doc.y, para).fillColor(TEXT).moveDown(0.6);
          break;
        case "note":
          doc.font("Helvetica-Bold").fontSize(10.5).fillColor("#5b2a86")
            .text(b.text, left, doc.y, { width, align: "center" }).fillColor(TEXT).moveDown(0.3);
          break;
        case "link":
          doc.font("Helvetica-Bold").fontSize(10.5).fillColor(BLUE)
            .text(b.text, left, doc.y, { width, link: b.text, underline: true })
            .fillColor(TEXT).moveDown(0.6);
          break;
        default:
          doc.font("Helvetica").fontSize(10.5).text(b.text, left, doc.y, para).moveDown(0.6);
      }
    });

    // Signature block (~95pt tall), kept together on one page.
    const sigHeight = 95;
    if (doc.y + 12 + sigHeight > limit()) {
      doc.addPage();
    } else {
      doc.moveDown(0.8);
    }
    const sigTop = doc.y;
    doc.font("Helvetica").fontSize(10.5).fillColor(TEXT).text("Signature:", left, sigTop + 30);
    if (signature) doc.image(signature, left + 70, sigTop, { fit: [200, 50] });
    doc.moveTo(left + 70, sigTop + 52).lineTo(left + 290, sigTop + 52)
      .strokeColor("#9aa4b2").lineWidth(0.8).stroke();
    doc.text(`Name: ${name}`, left, sigTop + 60, { width: width / 2 });
    doc.text(`Date: ${formatToronto(signedAt, false)}`, left + width / 2, sigTop + 60,
      { width: width / 2, align: "right" });
    doc.fontSize(8).fillColor("#6b7280").text(
      `Signed electronically on ${formatToronto(signedAt, true)}` +
        (audit ? ` · ${audit}` : ""),
      left, sigTop + 80, { width });
    doc.end();
  });
}

module.exports = {
  AGENCY,
  LETTER_IDS,
  DEFAULT_POSITION,
  DEFAULT_JOB_DESCRIPTION,
  normalizeFields,
  buildLetters,
  renderLetterPdf,
};
