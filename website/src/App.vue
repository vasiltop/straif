<script setup>
	import { onMounted, ref } from 'vue';

	const BASE_URL = "https://straifapi.pumped.software";
	const PAGE_SIZE = 10;
	const runs = ref([]);
	const total_count = ref(0);
	const current_page = ref(1);
	const current_map = ref('map_rooftops');
	const current_mode = ref('target');

	const MAP_LABELS = {
		'Tutorial': 'Tutorial',
		'map_rooftops': 'Rooftops',
		'map_streets': 'Streets',
		'map_flow': 'Flow',
		'map_line': 'Line',
		'map_rookie': 'Rookie',
		'map_dawn': 'Dawn',
		'map_structure': 'Structure',
		'map_graybox': 'Graybox',
		'map_graybox2': 'Graybox 2',
		'map_subway': 'Subway',
		'map_rooftops2': 'Rooftops 2',
		'map_slope': 'Slope',
		'map_taurus': 'Taurus'
	}

	const MODE_MAP_REF = {
		target: [
			'Tutorial',
			'map_rooftops',
			'map_streets',
			'map_flow',
			'map_structure',
			'map_graybox',
			'map_graybox2',
			'map_subway',
			'map_rooftops2',
		],
		bhop: [
			'Tutorial',
			'map_rooftops',
			'map_streets',
			'map_flow',
			'map_line',
			'map_rookie',
			'map_dawn',
			'map_structure',
			'map_graybox',
			'map_graybox2',
			'map_subway',
			'map_rooftops2',
			'map_slope',
			'map_taurus'
		]
	}

	async function load_runs() {
		let res = await fetch(`${BASE_URL}/leaderboard/mode/${current_mode.value}/maps/${current_map.value}/runs?page=${current_page.value - 1}`);
		let json = await res.json();
		runs.value = json.data.runs;
		console.log(json)
		total_count.value = Math.ceil(json.data.total / PAGE_SIZE);
		modify_page(0);
	}

	function modify_page(amount) {
		const old = current_page.value;
		current_page.value += amount;
		current_page.value = Math.min(Math.max(current_page.value, 1), Math.max(total_count.value, 1));

		if (current_page.value != old) {
			load_runs();
		}
	}

	onMounted(load_runs);

</script>

<template>
	<div class="hero flex-col">
		<h1> Straif Leaderboard</h1>

		<div class="flex"> 
			<label for="mode"> Mode: </label>
			<select id="mode" v-model="current_mode" @change="load_runs()">
				<option value="target"> Target </option>
				<option value="bhop"> Bhop </option>
			</select>
			<label for="map"> Map: </label>
			<select id="map" v-model="current_map" @change="load_runs()">
				<option
					v-for="map in MODE_MAP_REF[current_mode]"
					:key="map"
					:value="map">
					{{ MAP_LABELS[map] }}
				</option>
			</select>
		</div>

		<table>
			<thead>
				<tr>
					<th> Position </th>
					<th> Player Name </th>
					<th> Time (s) </th>
					<th> Date Submitted </th>
				</tr>
			</thead>

			<tbody>
				<tr v-if="runs.length === 0">
					<td colspan="4" style="text-align: center;">Unavailable</td>
				</tr>
				<tr v-else v-for="(run, index) in runs" :key="run.id || index">
					<th> {{ ((current_page - 1) * PAGE_SIZE) + index + 1 }}</th>
					<th> {{ run.username }}</th>
					<th> {{ run.time_ms / 1000 }} </th>
					<th> {{ run.created_at.slice(0, "2025-08-05".length)}}</th>
				</tr>
			</tbody>
		</table>
		
		<div class="flex">
			<button @click="modify_page(-1)"> &lt </button>
			<p> Page {{ current_page }} of {{ total_count }}</p>
			<button @click="modify_page(1)"> &gt </button>
		</div>
	</div>
</template>

<style>

body {
  margin: 0;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  background-color: lightgray;
}

.hero {
  width: 100%;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  padding: 2rem;
}

h1 {
  font-size: 2rem;
  font-weight: bold;
  margin-bottom: 1.5rem;
  color: black;
}

.flex {
  display: flex;
  gap: 1rem;
  margin-bottom: 1rem;
  align-items: center;
}

select {
  padding: 0.4rem 0.6rem;
  border-radius: 6px;
  border: 1px solid #ccc;
  background-color: white;
  font-size: 1rem;
  cursor: pointer;
  transition: border-color 0.2s;
}

select:hover {
  border-color: black;
}

table {
  width: 100%;
  max-width: 800px;
  border-collapse: collapse;
  margin-top: 1rem;
  background-color: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

thead {
  background-color: gray;
  color: white;
}

th, td {
  padding: 0.75rem 1rem;
  text-align: left;
}

tbody tr:nth-child(even) {
  background-color: #f2f2f2;
}

tbody tr:hover {
  background-color: #c3c8ce;
}

button {
  padding: 0.4rem 0.8rem;
  border: none;
  border-radius: 6px;
  background-color: gray;
  color: white;
  font-weight: bold;
  cursor: pointer;
  transition: background-color 0.2s;
}

button:hover {
  background-color: darkgray;
}

p {
  margin: 0 1rem;
  font-weight: bold;
}
</style>
