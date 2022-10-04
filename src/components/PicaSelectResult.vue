<script setup>
defineProps({ result: Object })
</script>

<template>
  <div v-if="result.error" class="alert alert-danger" role="alert">
    <a v-if="result.url" class="float-end alert-link" :href="result.url">API</a>
    <div>Error {{result.error.status}}: {{result.error.message}}</div>
  </div>
  <div v-if="result.pica">
    <div>
      <a v-if="result.url" class="float-end alert-link" :href="result.url">API</a>
      Ergebnis (PICA-Datensätze)
    </div>
    <pre><code>{{result.pica}}</code></pre>
  </div>
  <div v-else-if="result.table">
    <div>
      <a v-if="result.url" class="float-end alert-link" :href="result.url">API</a>
      Ergebnis (Tabelle)
    </div>
  </div>
</template>
