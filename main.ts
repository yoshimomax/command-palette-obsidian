import { App, Modal, Notice, Plugin, PluginSettingTab, Setting } from "obsidian";

interface CommandPaletteSettings {
	showRecentCommands: boolean;
	maxRecentCommands: number;
}

const DEFAULT_SETTINGS: CommandPaletteSettings = {
	showRecentCommands: true,
	maxRecentCommands: 5,
};

export default class CommandPalettePlugin extends Plugin {
	settings: CommandPaletteSettings;

	async onload() {
		await this.loadSettings();

		this.addCommand({
			id: "open-greeting",
			name: "Open Greeting",
			callback: () => {
				new GreetingModal(this.app).open();
			},
		});

		this.addCommand({
			id: "show-notice",
			name: "Show Notice",
			callback: () => {
				new Notice("Hello from Command Palette Plugin!");
			},
		});

		this.addSettingTab(new CommandPaletteSettingTab(this.app, this));
	}

	onunload() {}

	async loadSettings() {
		this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
	}

	async saveSettings() {
		await this.saveData(this.settings);
	}
}

class GreetingModal extends Modal {
	constructor(app: App) {
		super(app);
	}

	onOpen() {
		const { contentEl } = this;
		contentEl.setText("Hello from Command Palette Plugin!");
	}

	onClose() {
		const { contentEl } = this;
		contentEl.empty();
	}
}

class CommandPaletteSettingTab extends PluginSettingTab {
	plugin: CommandPalettePlugin;

	constructor(app: App, plugin: CommandPalettePlugin) {
		super(app, plugin);
		this.plugin = plugin;
	}

	display(): void {
		const { containerEl } = this;
		containerEl.empty();

		new Setting(containerEl)
			.setName("Show recent commands")
			.setDesc("Display recently used commands at the top of the palette")
			.addToggle((toggle) =>
				toggle
					.setValue(this.plugin.settings.showRecentCommands)
					.onChange(async (value) => {
						this.plugin.settings.showRecentCommands = value;
						await this.plugin.saveSettings();
					})
			);

		new Setting(containerEl)
			.setName("Max recent commands")
			.setDesc("Maximum number of recent commands to show")
			.addText((text) =>
				text
					.setPlaceholder("5")
					.setValue(String(this.plugin.settings.maxRecentCommands))
					.onChange(async (value) => {
						this.plugin.settings.maxRecentCommands = Number(value) || 5;
						await this.plugin.saveSettings();
					})
			);
	}
}
