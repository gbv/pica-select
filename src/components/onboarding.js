import { ref } from 'vue'

import { VOnboardingWrapper, useVOnboarding } from 'v-onboarding'

import 'v-onboarding/dist/style.css'

const obWrapper = ref(null)

export const onboarding = useVOnboarding(obWrapper)

export { VOnboardingWrapper, obWrapper }

const steps = [
  [
    "database",
    "Datenbank",
    "Die Auswahl der Datenbank bestimmt, in welchen Datensätzen gesucht wird."
  ],[
    "query",
    "Abfrage",
    "Die Suchabfrage muss in CQL-Syntax gestellt werden. Alle im OPAC möglichen Suchschlüssel können verwendet werden."
  ],[
    "levels",
    "Datensatz-Ebenen",
    "Die gefundenen Datensätze können in Lokal- (Ebene 1) oder Exemplarsätze (Ebene 2) aufgeteilt werden."
  ],[
    "filter",
    "Datensatz-Filter",
    "Das Suchergebnis kann zusätzlich auf Datensätze reduziert werden, die bestimmte Kriterien erfüllen. Die Syntax für Filter-Ausdrücke ist an anderer Stelle erklärt."
  ],[
    "select",
    "Auswahl von Feldern bzw. Werten",
    "Das Ergebnis kann auf bestimmte Felder (bei PICA+ Formaten) bzw. auf Unterfeld-Werte (bei tabellarischen Formaten) beschränkt werden."
  ],[
    "pica-formats",
    "PICA+",
    "Liefert die Datensätze (bzw. ausgewählte vollständige Felder) in einem PICA+ Format zurück."
  ],[
    "tabular-formats",
    "Tabellarisch",
    "Liefert eine Tabelle mit ausgewählten Unterfeld-Werten. Standardmäßig wird nur der erste Wert eines Datensatz berücksichtigt. Wenn alle Werte brücksichtigt werden sollen, muss ein Trenner angegeben werden."
  ]
]

export const onboardingSteps = steps.map(([id, title, description]) => {
  return {
    attachTo: { element: `#${id}` },
    content: { title, description }
  }
})

export const onboardingOptions = {
  labels: {
    previousButton: 'Zurück',
    nextButton: 'Weiter',
    finishButton: 'OK'
  }
}
