<script setup>
defineProps({
  api: {
    type: String,
    required: true
  }
})

import { ref } from 'vue'

const databases = ref({})
const dbkey = ref(undefined)
const format = ref("")
const browser = ref(true)
const splitlevels = ref(true)
</script>

<template>    
  <form :action="`${api}/select`" method="get">
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
                <option v-for="(db,key) of databases" :value="key">
                  {{db.title.de || key}}
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
            <input type="text" name="query" class="form-control" style="width:100%"/>
            <div class="form-text">
              in
              <a href="https://wiki.k10plus.de/display/K10PLUS/SRU">SRU CQL-Syntax</a>
            </div>
          </div>
          <div class="col-auto">
            <button type="submit" class="btn btn-primary">Abfragen</button>
          </div>
          <div class="col-auto">
            <div class="form-check form-switch">
              <input class="form-check-input" type="checkbox" role="switch" id="splitlevels" v-model="splitlevels">
              <label class="form-check-label" for="splitlevels">Exemplare einzeln</label>
            </div>
            <div class="form-check form-switch">
              <input class="form-check-input" type="checkbox" role="switch" id="browser" v-model="browser">
              <label class="form-check-label" for="browser">Ergebnis im Browser</label>
            </div>
          </div>
        </td>
      </tr>
      <tr>
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
              noch nicht umgesetzt
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label>Format</label>
        </th>
        <td class="row align-items-center">
          <div class="col-auto">
            <div class="form-check form-check-inline">
              <label for="format-csv" class="form-check-label">Tabelle</label>
            </div>
            <div class="form-check form-check-inline">
              <input class="form-check-input" type="radio" name="format" id="format-csv" value="csv" v-model="format">
              <label class="form-check-label" for="format-csv">CSV</label>
            </div>
            <div class="form-check form-check-inline">
              <input class="form-check-input" type="radio" name="format" id="format-tsv" value="tsv" v-model="format">
              <label class="form-check-label" for="format-tsv">TSV</label>
            </div>
            <div class="form-check form-check-inline">
              <input class="form-check-input" type="radio" name="format" id="format-ods" value="ods" v-model="format">
              <label class="form-check-label" for="format-ods">Spreadsheet</label>
            </div>
          </div>
          <div class="col-auto">
            <div class="form-check form-check-inline">
              <label for="format-pp" class="form-check-label">PICA+</label>
            </div>
              <div class="form-check form-check-inline">
              <input class="form-check-input" type="radio" name="format" id="format-pp" value="pp" v-model="format">
              <label class="form-check-label" for="format-pp">Plain</label>
            </div>
            <div class="form-check form-check-inline">
              <input class="form-check-input" type="radio" name="format" id="format-norm" value="norm" v-model="format">
              <label class="form-check-label" for="format-norm">Normalisiert</label>
            </div>
            <div class="form-check form-check-inline">
              <input class="form-check-input" type="radio" name="format" id="format-json" value="json" v-model="format">
              <label class="form-check-label" for="format-json">JSON</label>
            </div>
          </div>
        </td>
      </tr>
      <tr>
        <th>
          <label>Auswahl</label>
        </th>
        <td v-if="format.match(/^(csv|tsv|ods)$/)">
           TODO:
           Unterfelder, Templates, Standardtabellen für {{format}}
        </td>
        <td v-else>
          TODO:
          PICA-Feldauswahl für {{format}} Serialisierung
        </td>
      </tr>
    </table>
  </form>
</template>

<script>
export default {
  mounted() {
    const statusEndpoint = this.api + "/select"
    fetch(statusEndpoint)
      .then(response => response.json())
      .then(res => {
        this.databases = res.databases
        this.dbkey = res.default_database
      })
  }
}
</script>

<style scoped>
th {
  padding-right: 1rem;
  padding-top: 0.5rem;
  vertical-align: top;
}
</style>

<style scoped>
code {
  color: #d63384;
  word-wrap: break-word;
}
a > code {
  color: rgb(96, 143, 219);
}
pre {
  background-color: #f7f7f9;
  padding: 1em;
  margin: 0.3em 0;
}
pre > code {
  color: #000;
}
input, label {
  display: inline-block;
}
form {
  padding: 0.5em 0em 0em 0em;
}
.msg {
  background: #def;
  border-color: #59d;
}
.msg.valid {
  border-color: #2d2;
  background: #dfd;
}
.msg.invalid {
  border-color: #e44;
  background: #fdd;
}

/* Boostrap-compatible */
/*
.row {
  display: flex;
  flex-wrap: wrap;
  margin-top: -1rem;
  margin-right: -0.5rem;
  margin-left: -0.5rem;
}
.align-items-center {
  align-items: center!important;
}
.row>* {
  padding-right: 0.5rem;
  padding-left: 0.5rem;
  margin-top: 1rem;
}
.col-auto {
  flex: 0 0 auto;
  width: auto;
}
.col-sm-7 {
  flex: 0 0 auto;
  width: 58.3%;
}
.form-control {
  width: 100%;
  border-radius: 0.375rem;
}
.col-form-label {
}
.form-text {
  margin-top: 0.25rem;
  font-size: .875em;
  color: #6c757d;
}
*/
</style>
