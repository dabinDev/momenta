function mergeChannels(chunks, length) {
  const data = new Float32Array(length)
  let offset = 0

  for (const chunk of chunks) {
    data.set(chunk, offset)
    offset += chunk.length
  }

  return data
}

function downsampleBuffer(buffer, sampleRate, targetRate) {
  if (targetRate === sampleRate) {
    return buffer
  }

  const ratio = sampleRate / targetRate
  const targetLength = Math.round(buffer.length / ratio)
  const result = new Float32Array(targetLength)
  let offsetResult = 0
  let offsetBuffer = 0

  while (offsetResult < result.length) {
    const nextOffsetBuffer = Math.round((offsetResult + 1) * ratio)
    let accum = 0
    let count = 0
    for (let index = offsetBuffer; index < nextOffsetBuffer && index < buffer.length; index += 1) {
      accum += buffer[index]
      count += 1
    }
    result[offsetResult] = count > 0 ? accum / count : 0
    offsetResult += 1
    offsetBuffer = nextOffsetBuffer
  }

  return result
}

function floatTo16BitPCM(output, offset, input) {
  for (let index = 0; index < input.length; index += 1, offset += 2) {
    const sample = Math.max(-1, Math.min(1, input[index]))
    output.setInt16(offset, sample < 0 ? sample * 0x8000 : sample * 0x7fff, true)
  }
}

function writeString(view, offset, value) {
  for (let index = 0; index < value.length; index += 1) {
    view.setUint8(offset + index, value.charCodeAt(index))
  }
}

function encodeWav(samples, sampleRate) {
  const buffer = new ArrayBuffer(44 + samples.length * 2)
  const view = new DataView(buffer)

  writeString(view, 0, 'RIFF')
  view.setUint32(4, 36 + samples.length * 2, true)
  writeString(view, 8, 'WAVE')
  writeString(view, 12, 'fmt ')
  view.setUint32(16, 16, true)
  view.setUint16(20, 1, true)
  view.setUint16(22, 1, true)
  view.setUint32(24, sampleRate, true)
  view.setUint32(28, sampleRate * 2, true)
  view.setUint16(32, 2, true)
  view.setUint16(34, 16, true)
  writeString(view, 36, 'data')
  view.setUint32(40, samples.length * 2, true)
  floatTo16BitPCM(view, 44, samples)

  return new Blob([view], { type: 'audio/wav' })
}

export async function createWavRecorder({ onSecond, maxSeconds = 60 } = {}) {
  if (!window.navigator.mediaDevices?.getUserMedia) {
    throw new Error('当前浏览器不支持麦克风录音')
  }

  const stream = await window.navigator.mediaDevices.getUserMedia({
    audio: {
      channelCount: 1,
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
  })

  const AudioContextClass = window.AudioContext || window.webkitAudioContext
  const audioContext = new AudioContextClass()
  const source = audioContext.createMediaStreamSource(stream)
  const processor = audioContext.createScriptProcessor(4096, 1, 1)
  const gainNode = audioContext.createGain()

  gainNode.gain.value = 0
  source.connect(processor)
  processor.connect(gainNode)
  gainNode.connect(audioContext.destination)

  const chunks = []
  let sampleLength = 0
  let elapsed = 0
  let stopped = false

  processor.onaudioprocess = (event) => {
    const channelData = event.inputBuffer.getChannelData(0)
    const copied = new Float32Array(channelData.length)
    copied.set(channelData)
    chunks.push(copied)
    sampleLength += copied.length
  }

  const timer = window.setInterval(() => {
    elapsed += 1
    onSecond?.(elapsed)
    if (elapsed >= maxSeconds) {
      stop().catch(() => {})
    }
  }, 1000)

  async function cleanup() {
    if (stopped) {
      return
    }
    stopped = true
    window.clearInterval(timer)
    processor.disconnect()
    source.disconnect()
    gainNode.disconnect()
    stream.getTracks().forEach((track) => track.stop())
    await audioContext.close()
  }

  async function stop() {
    if (stopped) {
      return null
    }

    await cleanup()

    if (!sampleLength) {
      return null
    }

    const merged = mergeChannels(chunks, sampleLength)
    const downsampled = downsampleBuffer(merged, audioContext.sampleRate, 16000)

    if (!downsampled.length) {
      return null
    }

    return {
      blob: encodeWav(downsampled, 16000),
      duration: elapsed,
    }
  }

  return {
    stop,
    cancel: cleanup,
  }
}
