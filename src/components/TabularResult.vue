<script setup>
defineProps({ table: Object })

// TODO: link ppn to opac, if known
</script>

<template>
  <table v-if="table.rows.length" class="table table-hover table-sm">
    <thead>
      <tr>
        <th v-for="column in table.columns">
          {{column.name}}
        </th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in table.rows">
        <td v-for="column in table.columns">          
          {{row[column.name]}}
        </td>
      </tr>
    </tbody>
  </table>
</template>
