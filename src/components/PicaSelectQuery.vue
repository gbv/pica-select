<script setup>
import { ref, onMounted, onUpdated, computed, watch, nextTick } from 'vue'

import OnboardingComponent from './OnboardingComponent.vue'
import { onboarding } from './onboarding.js'

const props = defineProps({
  api: {
    type: String,
    required: true
  },
  modelValue: { // result
    type: Object,
    default: () => ({})
  }
})

const emit = defineEmits(['update:modelValue'])

// set via API endpoint /status
const databases = ref(undefined)

// query/form fields
const dbkey = ref(undefined)
const format = ref("plain")
const query = ref("")
const level = ref("0")
const select = ref("")
const reduce = ref("")
const separator = ref("; ")
const delimit = ref(false)
const filter = ref("") // TODO: compute from ILN and SST
const formFields = { dbkey, format, query, level, select, reduce, separator, delimit, filter }

// additional form fields and calculated values
const selections = ref([])
const addSelection = ref("")
const browser = ref(true)
const apiRequestURL = ref("")
const clientRequestURL = ref("")
const tabular = ref(false)
const cliCommand = ref("")

// TODO: use as help
const filterFields = {
  sst: { name: "Sonderstandort", pica: "" },
  iln: { name: "ILN", pica: "" }
}

watch(addSelection, value => {
  if (value !== "") {
    select.value += value+"\n"
    addSelection.value = ""
  }
})

function resizeTextarea() {
  const area = document.getElementById('textarea-select')
  if (area) {
    area.style.height = area.scrollHeight + 'px'
  }
}
watch(select, resizeTextarea)

// called when any query/form field changes
watch([dbkey, format, query, level, select, reduce, separator, delimit, filter],
  ([dbkey, format, query, level, select, reduce, separator, delimit, filter]) => {

  const isTabular = format.match(/^(csv|tsv|ods|table)$/)
  tabular.value = isTabular

  const fields = { dbkey, format, query }
  if (level != "0") {
    fields.level = level
  }
  if (filter.trim() !== "") {
    fields.filter = filter
  }
  if (isTabular) {
    if (delimit) {
      fields.separator = separator
    }
    fields.select = select
  } else if (reduce != "") {
    fields.reduce = reduce
  }

  const params = new URLSearchParams(fields)
  apiRequestURL.value = `${props.api}/select?${params}`
  window.history.replaceState({}, "", `?${params}`)

  fields.format = isTabular ? 'table' : 'plain'
  clientRequestURL.value = `${props.api}/select?${new URLSearchParams(fields)}`


/*
  const db = databases.value[dbkey]
  if (db && query) {
    cliCommand.value = `catmandu convert SRU --base ${db.srubase} --recordSchema picaxml --parser picaxml \\
                     --query ${shellEscape(query)} ` 
    // TODO: total => $limit
    if (isTabular) {
    } else {
      cliCommand.value += `to PICA --type ${format}`
    }
  } else {
    cliCommand.value = ""
  }
*/
})

const fetchAPI = async url => {
  emit("update:modelValue", { loading: true, url })
  return fetch(url)
    .then(async res => {
      var data
      try {
        if (res.headers.get("content-type").match(/^text/)) {
          data = await res.text()
        } else {
          data = await res.json()
        }
      } catch {
        throw { message: "API-Antwort ist kein JSON!", url }
      } 

      if (res.ok) {
        return data
      } else {
        throw { message: data.message, url, status: res.status }
      }
    })
    .catch(e => {
      const message = e.message == "Failed to fetch" ? "API nicht erreichbar" : e.message
      throw { message, url }
    })
}


function setFormFromURL() {
  var triggerSubmit

  const params = new URLSearchParams(window.location.search)
  for (let name in formFields) {
    if (params.has(name)) {
      triggerSubmit = true
      formFields[name].value = params.get(name)
    }
  }

  if (triggerSubmit) {
    nextTick(() => { submit() })
  }

  resizeTextarea()
}

// TODO: this is not triggered when back/forward is clicked - seems like Vue catches it?
// window.addEventListener('popstate', () => { console.log("popstate") })

onMounted(() => {
  fetchAPI(`${props.api}/status`)
    .then(res => {
      selections.value = res.selections
      databases.value = res.databases || {}
      if (!dbkey.value) {
        dbkey.value = res.default_database
      }
      setFormFromURL()
      if (!query.value) {
        onboarding.start()
      }
    })
    .catch(error => emit("update:modelValue", { error }))
})

function submit() {
  if (browser.value) {
    window.history.pushState({}, "")
  } else {
    window.location.href = apiRequestURL
    return
  }

  fetchAPI(clientRequestURL.value)
    .then(data => {
      const result = { url: apiRequestURL.value, count: 0 }
      if (tabular.value) {
        result.table = data
        result.count = data.rows.length
      } else if (data.length)  {          
        result.count = data.split("\n").filter(l => l === "").length
        result.pica = data
      }
      emit("update:modelValue", result)
    })
    .catch(error => {
      error.url = apiRequestURL.value 
      emit("update:modelValue", { error })
    })
}

const shellEscape = arg => `'${arg.replace(/'/g, `'\\''`)}'`
</script>

<template>  
  <div>
  <OnboardingComponent />
  <form :action="`${api}/select`" method="get" v-on:submit.prevent="submit" v-if="databases">
    <table>
      <tr>
        <th>
          <label for="database">Datenbank</label>
        </th>
        <td style="width:100%">
          <div class="row align-items-top">
            <div class="col-5">
              <select name="database" class="form-control" v-model="dbkey" id="database">
                <option disabled value="">Bitte auswählen</option>
                <option v-for="(db,key) of databases" :value="key" :key="key">
                  {{db.title.de || db.title.en || key}}
                </option>
              </select>
            </div>
            <div class="col-5">
              <a :href="databases[dbkey].url" v-if="databases[dbkey]">{{databases[dbkey].url}}</a>
            </div>
            <div class="col-2">
              <a @click="onboarding.start()" href="#" style="padding-right: 0.5em">Hilfe</a>
              <a v-if="apiRequestURL" :href="apiRequestURL">API</a>              
              <br>
              <input class="form-check-input" type="checkbox" role="switch" id="browser" v-model="browser">
              <label class="form-check-label" for="browser">im Browser</label>
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label for="query">Abfrage</label>
        </th>
        <td class="row align-items-top">
          <div class="col" id="query">
            <input type="text" name="query" class="form-control" style="width:100%" v-model="query"/>
            <div class="form-text">
              in
              <a href="https://wiki.k10plus.de/display/K10PLUS/SRU">SRU CQL-Syntax</a>
              z.B. <code @click.left="query='pica.isb=978-3-89401-810-8'">pica.isb=978-3-89401-810-8</code>
            </div>
          </div>
          <div class="col-auto">
            <button type="submit" class="btn btn-primary">Abfragen</button>
          </div>
          <div class="col-auto" id="levels">
            <div class="form-check form-switch">
              <select name="database" class="form-control" v-model="level">
                <option value="0">Gesamter Datensatz</option>
                <option value="1">Lokaldatensätze</option>
                <option value="2">Exemplare</option>
              </select>
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label>Filter</label>
        </th>
        <td class="row align-items-center" id="filter">
          <div class="col-12">
            <input type="text" v-model="filter" class="form-control" style="width:100%"/>
            <div class="form-text">
                z.B.: <code>101@$a != '22' &amp;&amp; 209A $f == '8/10'</code>
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label>Auswahl</label>
        </th>
        <td id="select">
          <div class="row" v-if="tabular">
            <div class="col">
              <textarea id="textarea-select" v-model="select" placeholder="Ein Feld pro Zeile" class="form-control"></textarea>
              <div class="form-text">
                Syntax pro Zeile <code>Name: Feld $codes</code>
              </div>
            </div>
            <div class="col-auto" v-if="selections && selections.length">
              <button 
                 type="button" class="btn btn-secondary"
                @click='select += selections.join("\n")+"\n"'
                  >⇐ Alle übernehmen</button>
              <select class="form-control" v-model="addSelection">
                <option value="">bitte auswählen</option>  
                <option v-for="s of selections" :value="s">{{s}}</option>
              </select>
            </div>
          </div>
          <div v-else>
            <input type="text" class="form-control" style="width:100%" v-model="reduce" />
            <div class="form-text">
              Einzelne PICA+ Felder in <a href="https://format.gbv.de/query/picapath">PICA Path</a>
              Syntax z.B. <code>003@, 021A, ...</code>
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label>Format</label>
        </th>
        <td class="row align-items-center">
          <table>
            <tr>
              <td id="pica-formats">
               <div class="form-check form-check-inline" @click.left="format='plain'">
                  <input class="form-check-input" type="radio" name="format" id="format-plain" value="plain" v-model="format">
                  <label class="form-check-label" for="format-plain">PICA Plain</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='plus'">
                  <input class="form-check-input" type="radio" name="format" id="format-plus" value="plus" v-model="format">
                  <label class="form-check-label" for="format-plus">Normalisiert</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='json'">
                  <input class="form-check-input" type="radio" name="format" id="format-json" value="json" v-model="format">
                  <label class="form-check-label" for="format-json">PICA/JSON</label>
                </div>
              </td>
              <td rowspan="2" v-if="tabular">
                <input class="form-check-input" type="checkbox" id="format-delimit" name="delimit" v-model="delimit">
                <label class="form-check-label" for="format-delimit">
                  Alle Werte berücksichtigen, getrennt mit:
                </label>
                <input type="text" name="separator" class="form-control" v-model="separator" style="width:4em;"/>
              </td>
            </tr>
            <tr>
              <td id="tabular-formats">
                <div class="form-check form-check-inline" @click.left="format='csv'">
                  <input class="form-check-input" type="radio" name="format" id="format-csv" value="csv" v-model="format">
                  <label class="form-check-label" for="format-csv">CSV</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='tsv'">
                  <input class="form-check-input" type="radio" name="format" id="format-tsv" value="tsv" v-model="format">
                  <label class="form-check-label" for="format-tsv">TSV</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='table'">
                  <input class="form-check-input" type="radio" name="format" id="format-table" value="table" v-model="format">
                  <label class="form-check-label" for="format-table">JSON Table</label>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <tr v-if="cliCommand">
        <th>
          <label>Kommandozeile</label>
        </th>
        <td>
          <pre><code>{{cliCommand}}</code></pre>
        </td>
      </tr>
    </table>
  </form>
  </div>
</template>

<style scoped>
table {
  border-spacing: 0rem 0.5rem;
  border-collapse: unset;
}
th {
  padding-right: 1rem;
  padding-top: 0.5rem;
  vertical-align: top;
}
.form-check-label {
  padding-left: 0.3rem;
  padding-right: 0.3rem;
  white-space: nowrap;
}
</style>
<style>
.v-onboarding-item__header-close {
  border: none;
}
</style>
