#include "WaveEdit.hpp"
#include <string.h>
#include <sndfile.h>


int userBankLen = BANK_LEN_MAX;
int bankGridWidth = 8;
int bankGridHeight = 8;

void setGlobalBankLen(int newLen) {
	if (newLen == userBankLen) return;

	userBankLen = (newLen > BANK_LEN_MAX) ? BANK_LEN_MAX : (newLen < 1) ? 1 : newLen;
	bankGridHeight = (userBankLen / 8);
	if (userBankLen % 8) bankGridHeight++;

	currentBank.setBankLen(userBankLen);
}


void Bank::setBankLen(int newLen) {
	bankLen = newLen;
}


int Bank::getBankLen() {
	return bankLen;
}


void Bank::clear() {
	// The lazy way
	memset(waves, 0, sizeof(waves));

	for (int i = 0; i < BANK_LEN_MAX; i++) {
		waves[i].commitSamples();
	}
}


void Bank::swap(int i, int j) {
	Wave tmp = waves[i];
	waves[i] = waves[j];
	waves[j] = tmp;
}


void Bank::shuffle() {
	for (int j = getBankLen() - 1; j >= 3; j--) {
		int i = rand() % j;
		swap(i, j);
	}
}


void Bank::setSamples(const float *in) {
	for (int j = 0; j < getBankLen(); j++) {
		memcpy(waves[j].samples, &in[j * WAVE_LEN], sizeof(float) * WAVE_LEN);
		waves[j].commitSamples();
	}
}


void Bank::getPostSamples(float *out) {
	for (int j = 0; j < getBankLen(); j++) {
		memcpy(&out[j * WAVE_LEN], waves[j].postSamples, sizeof(float) * WAVE_LEN);
	}
}


void Bank::duplicateToAll(int waveId) {
	for (int j = 0; j < BANK_LEN_MAX; j++) {
		if (j != waveId)
			waves[j] = waves[waveId];
		// No need to commit the wave because we're copying everything
	}
}


void Bank::save(const char *filename) {
	FILE *f = fopen(filename, "wb");
	if (!f)
		return;
	fwrite(this, sizeof(*this), 1, f);
	fclose(f);
}


void Bank::load(const char *filename) {
	clear();

	FILE *f = fopen(filename, "rb");
	if (!f)
		return;
	fread(this, sizeof(*this), 1, f);
	fclose(f);

	for (int j = 0; j < BANK_LEN; j++) {
		waves[j].commitSamples();
	}
	setGlobalBankLen(bankLen ? bankLen : BANK_LEN_MAX);
}


void Bank::saveWAV(const char *filename) {
	SF_INFO info;
	info.samplerate = 48000;
	info.channels = 1;
	info.format = SF_FORMAT_WAV | SF_FORMAT_PCM_32 | SF_FORMAT_FLOAT | SF_ENDIAN_LITTLE;
	SNDFILE *sf = sf_open(filename, SFM_WRITE, &info);
	if (!sf)
		return;

	for (int j = 0; j < BANK_LEN; j++) {
		sf_write_float(sf, waves[j].postSamples, WAVE_LEN);
	}

	sf_close(sf);
}


void Bank::loadWAV(const char *filename) {
	clear();

	int newBankLen = 0;
	SF_INFO info;
	SNDFILE *sf = sf_open(filename, SFM_READ, &info);
	if (!sf)
		return;

	for (int i = 0; i < getBankLen(); i++) {
		sf_count_t readCount = sf_read_float(sf, waves[i].samples, WAVE_LEN);
		if (readCount) {
			waves[i].commitSamples();
			newBankLen++;
		}
		if (readCount < WAVE_LEN) {
			setGlobalBankLen(newBankLen);
			break;
		}
	}

	sf_close(sf);
}


void Bank::loadWAVToFit(const char *filename) {
	clear();

	SF_INFO info;
	SNDFILE *sf = sf_open(filename, SFM_READ, &info);
	if (!sf)
		return;

	int fileLength = info.frames * info.channels;
	int bankLength = getBankLen() * WAVE_LEN;

	if (fileLength == bankLength) {
		sf_close(sf);
		loadWAV(filename);
		return;
	}

	float *fileSamples = new float[fileLength];
	float *bankSamples = new float[bankLength];

	sf_read_float(sf, fileSamples, fileLength);
	resample(fileSamples, fileLength, bankSamples, bankLength, (double)bankLength / (double)fileLength);

	for (int i = 0; i < getBankLen(); i++) {
		memcpy(waves[i].samples, bankSamples + (i * WAVE_LEN), sizeof(float) * WAVE_LEN);
		waves[i].commitSamples();
	}

	delete[] bankSamples;
	delete[] fileSamples;
}


void Bank::saveWaves(const char *dirname) {
	for (int b = 0; b < getBankLen(); b++) {
		char filename[1024];
		snprintf(filename, sizeof(filename), "%s/%02d.wav", dirname, b);

		waves[b].saveWAV(filename);
	}
}

bool Bank::allInCycle() {
	for (int i = 0; i < getBankLen(); i++) {
		if (!waves[i].cycle) return false;
	}
	return true;
}


bool Bank::allInNormalize() {
	for (int i = 0; i < getBankLen(); i++) {
		if (!waves[i].normalize) return false;
	}
	return true;
}


bool Bank::allInZerox() {
	for (int i = 0; i < getBankLen(); i++) {
		if (!waves[i].zerox) return false;
	}
	return true;
}


bool Bank::allInPhaseBash() {
	for (int i = 0; i < getBankLen(); i++) {
		if (!waves[i].phasebash) return false;
	}
	return true;
}


void Bank::cycleAll(bool way) {
	for (int i = 0; i < getBankLen(); i++) {
		waves[i].cycle = way;
		waves[i].updatePost();
		historyPush();
	}
}


void Bank::normalizeAll(bool way) {
	for (int i = 0; i < getBankLen(); i++) {
		waves[i].normalize = way;
		waves[i].updatePost();
		historyPush();
	}
}


void Bank::zeroxAll(bool way) {
	for (int i = 0; i < getBankLen(); i++) {
		waves[i].zerox = way;
		waves[i].updatePost();
		historyPush();
	}
}


void Bank::phaseBashAll(bool way) {
	for (int i = 0; i < getBankLen(); i++) {
		waves[i].phasebash = way;
		waves[i].updatePost();
		historyPush();
	}
}


