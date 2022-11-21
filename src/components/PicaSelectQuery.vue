<script setup>
import { ref, onMounted, computed } from 'vue'

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

// is set via API endpoint /status
const databases = ref({})

// query and/or form parameters
const dbkey = ref(undefined)
const format = ref("pp")
const query = ref("")
const select = ref("")
const reduce = ref("")
const browser = ref(true)
const levels = ref("0")
const delimit = ref(false)
const separator = ref("; ")

const tabular = computed(() => format.value.match(/^(csv|tsv|ods|table)$/))

onMounted(() => {
  const url = `${props.api}/status`
  fetch(url)
    .then(res => {
      if (res.ok) {
        try { return res.json() } catch { } // eslint-disable-line no-empty 
      }
      return { error: "API nicht erreichbar!" }
    })
    .then(res => {
      // TODO: disable form
      databases.value = res.databases || {}
      dbkey.value = res.default_database
      if (res.error) {
        emit("update:modelValue", { error: { message: res.error }, url })
      }
    })
})

function selectURL(params) {
  for (let key in params) {
    if (typeof params[key] === 'undefined' || params[key] === "") {
      delete params[key]
    }
  }
  return `${props.api}/select?` + new URLSearchParams(params)
}

// TODO: move to parent component and do form validation?
function submit() {
  const params = {
    db: dbkey.value,
    query: query.value,
    format: format.value,
    reduce: reduce.value,
    levels: levels.value,
//    separator: separator.value
  }    
  if (tabular) {
    params.select = select.value
  }
  const apiURL = selectURL(params)
  if (!browser.value) {
    window.location.href = selectURL
    return
  }
  params.format = tabular ? 'tsv' : 'pp'
  fetch(selectURL(params))
    .then(async res => {
      if (!res.ok) {
        var error
        try {
          error = await res.json()
        } catch {
          error = { message: "Malformed API response", status: 500 }
        }
        throw error
      }        
      return params.format == "json" ? res.json() : res.text()
    })
    .then(data => {
      const result = { url: apiURL }
      if (tabular) {
        // TODO: parse tsv/csv or get as JSON
        result.table = data
      } else {
        result.count = data.split("\n").filter(l => l === "").length 
        result.pica = data
      }
      emit("update:modelValue", result)
    })
    .catch(error => {
      emit("update:modelValue", { url, params, error })
    })
}
</script>

<template>    
  <form :action="`${api}/select`" method="get" v-on:submit.prevent="submit">
  <div class="form-switch float-end">
    <input class="form-check-input" type="checkbox" role="switch" id="browser" v-model="browser">
    <label class="form-check-label" for="browser">im Browser</label>
  </div>
  <h2>Abfrage</h2>
    <table>
      <tr>
        <th>
          <label for="database">Datenbank</label>
        </th>
        <td style="width:100%">
          <div class="row align-items-top">
            <div class="col-auto">
              <select name="database" class="form-control" v-model="dbkey">
                <option disabled value="">Bitte auswählen</option>
                <option v-for="(db,key) of databases" :value="key" :key="key">
                  {{db.title.de || db.title.en || key}}
                </option>
              </select>        
            </div>
            <div class="col-auto" v-if="databases[dbkey]">
              <a :href="databases[dbkey].url">{{databases[dbkey].url}}</a>
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label for="query">Abfrage</label>
        </th>
        <td class="row align-items-top">
          <div class="col-sm-8">
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
          <div class="col-auto">
            <div class="form-check form-switch">
              <select name="database" class="form-control" v-model="levels">
                <option value="0">Gesamter Datensatz</option>
                <option value="01">Lokaldatensätze</option>
                <option value="012">Exemplare</option>
              </select>
            </div>
          </div>
        </td>
      </tr>
      <!--tr>
        <th>
          <label>Filter</label>
        </th>
        <td class="row align-items-center">
          <div class="col-auto">
            <label class="col-form-label">
              Sonderstandort          
            </label>
          </div>
          <div class="col-auto">
            <input type="text" name="sst" class="form-control" disabled/>
          </div>
          <div class="col-auto">
            <div class="form-text">
              NOCH NICHT UMGESETZT
            </div>
          </div>
        </td>
      </tr-->
      <tr>
        <th>
          <label>Format</label>
        </th>
        <td class="row align-items-center">
          <table>
            <tr>
              <td>
               <div class="form-check form-check-inline" @click.left="format='pp'">
                  <input class="form-check-input" type="radio" name="format" id="format-pp" value="pp" v-model="format">
                  <label class="form-check-label" for="format-pp">PICA Plain</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='norm'">
                  <input class="form-check-input" type="radio" name="format" id="format-norm" value="norm" v-model="format">
                  <label class="form-check-label" for="format-norm">Normalisiert</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='json'">
                  <input class="form-check-input" type="radio" name="format" id="format-json" value="json" v-model="format">
                  <label class="form-check-label" for="format-json">PICA/JSON</label>
                </div>
              </td>
              <td rowspan="2" v-if="tabular">
                <input class="form-check-input" type="checkbox" id="format-delimit" name="delimit" v-model="delimit">
                <label class="form-check-label" for="format-delimit">
                  Unterfelder trennen mit:
                </label>
                <input type="text" name="separator" class="form-control" v-model="separator" style="width:4em;"/>
              </td>
            </tr>
            <tr>
              <td>
                <div class="form-check form-check-inline" @click.left="format='csv'">
                  <input class="form-check-input" type="radio" name="format" id="format-csv" value="csv" v-model="format" disabled>
                  <label class="form-check-label" for="format-csv">CSV</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='tsv'">
                  <input class="form-check-input" type="radio" name="format" id="format-tsv" value="tsv" v-model="format">
                  <label class="form-check-label" for="format-tsv">TSV</label>
                </div>
                <div class="form-check form-check-inline" @click.left="format='ods'">
                  <input class="form-check-input" type="radio" name="format" id="format-ods" value="ods" v-model="format" disabled>
                  <label class="form-check-label" for="format-ods">Spreadsheet</label>
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
      <tr>
        <th>
          <label>Auswahl</label>
        </th>
        <td v-if="tabular">
           <textarea v-model="select" placeholder="Ein Feld pro Zeile" class="form-control"></textarea>
           <div class="form-text">               
            Syntax pro Zeile <code>Name: Feld $codes</code>
            TODO: Standardtabellen
           </div>
        </td>
        <td v-else>
          <input type="text" class="form-control" style="width:100%" v-model="reduce" />
          <div class="form-text">
            Einzelne PICA+ Felder in <a href="https://format.gbv.de/query/picapath">PICA Path</a>
            Syntax z.B. <code>003@, 021A, ...</code>
          </div>
        </td>
      </tr>
    </table>
  </form>
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

