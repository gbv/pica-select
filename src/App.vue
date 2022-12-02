<script setup>
import { ref } from "vue"
import { name, version } from '../package.json'

import "bootstrap/dist/css/bootstrap.css"

import PicaSelectQuery from './components/PicaSelectQuery.vue'
import PicaResult from "./components/PicaResult.vue"
import TabularResult from "./components/TabularResult.vue"

const result = ref({})

const api = import.meta.env.MODE === "production" ? "." : "http://localhost:5000"
</script>

<template>
  <PicaSelectQuery :api="api" v-model="result" class="container pica-select-search"/>
  <section v-if="result.loading" class="container alert alert-info">
    Bitte warten...
  </section>
  <section v-else-if="result.error" class="container alert alert-danger">
    <a v-if="result.error.url" class="float-end alert-link" :href="result.error.url">API</a>
    Fehler {{result.error.status || 500}}: {{result.error.message}}
  </section>
  <section v-else-if="result.url" class="container">      
    <div class="float-end" v-if="result.table">
      <ul class="list-inline">
        <li v-for="format of 'tsv,csv,table'.split(',')" class="list-inline-item">
          <a class="alert-link" :href="result.url.replace(/format=[a-z]+/,'format='+format)">
            {{format.toUpperCase()}}
          </a>
        </li>
      </ul>
    </div>
    <a v-else class="float-end alert-link" :href="result.url">API</a>
    <div v-if="result.count > 0"> 
      <h2>
        Ergebnis
        <small v-if="result.count > 1">({{result.count}} Datensätze)</small>
        <small v-else>(1 Datensatz)</small>
      </h2>
      <PicaResult v-if="result.pica" :records="result.pica"/>
     <TabularResult v-else-if="result.table" :table="result.table" />
    </div>
    <div v-else>
      Es wurde nichts gefunden.
    </div>
  </section>
  <footer class="container">
    <p>
      <a href="https://github.com/gbv/pica-select">{{name}}</a> {{version}}
      at <a :href="api">{{api}}</a>
      &nbsp;
      <a :href="api+'/status'">/status</a>
    </p>
  </footer>
</template>

<style>
.alert {
  border: none;
}
section.container, .pica-select-search{
  padding: 1rem;
  margin-bottom: 1rem;
  border-radius: 0;
  box-shadow: 0 4px 5px 0 rgb(0 0 0 / 14%), 0 1px 10px 0 rgb(0 0 0 / 12%), 0 2px 4px -1px rgb(0 0 0 / 30%);
}
footer {
  padding-top: 2em;
  color: #666;
}
</style>
