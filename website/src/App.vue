<script setup>
	import { onMounted, ref } from 'vue';

	const BASE_URL = "https://straifapi.pumped.software"
	const PAGE_SIZE = 10;
	const runs = ref([]);
	const total_count = ref(0);
	const current_page = ref(1);
	const current_map = ref('map_rooftops');

	async function load_runs() {
		let res = await fetch(`${BASE_URL}/leaderboard/${current_map.value}?page=${current_page.value - 1}`);
		let json = await res.json();
		runs.value = json.data;
		total_count.value = Math.ceil(json.count / PAGE_SIZE);
		modify_page(0);
	}

	function modify_page(amount) {
		const old = current_page.value;
		current_page.value += amount;
		current_page.value = Math.min(Math.max(current_page.value, 1), total_count.value); 

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
			<label for="map"> Map: </label>
			<select id="map" v-model="current_map" @change="load_runs()">
				<option value="Tutorial"> Tutorial </option>
				<option value="map_rooftops"> Rooftops </option>
				<option value="map_streets"> Streets </option>
				<option value="map_graybox"> Graybox </option>
				<option value="map_graybox2"> Graybox 2 </option>
				<option value="map_subway"> Subway </option>
				<option value="map_rooftops2"> Rooftops 2 </option>
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
				<tr v-for="(run, index) in runs">
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
		margin: 0px;
		width: 100vw;
		height: 100vh;
	}

	#app {
		width: 100%;
		height: 100%;
	}

	.hero {
		width: 100%;
		height: 100%;
		align-items: center;
		justify-content: center;
	}
	
	.flex {
		display: flex;
		gap: 2px;
	}

	.flex-col {
		display: flex;
		flex-direction: column;
	}
</style>
