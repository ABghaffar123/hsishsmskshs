import { useState, useEffect } from 'react'

const STORAGE_KEY = 'keep-clone-notes'

export function useNotes() {
  const [notes, setNotes] = useState([])
  const [loading, setLoading] = useState(true)

  // Load notes from localStorage on mount
  useEffect(() => {
    try {
      const savedNotes = localStorage.getItem(STORAGE_KEY)
      if (savedNotes) {
        setNotes(JSON.parse(savedNotes))
      }
    } catch (error) {
      console.error('Error loading notes:', error)
    } finally {
      setLoading(false)
    }
  }, [])

  // Save notes to localStorage whenever they change
  const saveNotes = (newNotes) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(newNotes))
    } catch (error) {
      console.error('Error saving notes:', error)
    }
  }

  const addNote = (note) => {
    const newNote = {
      ...note,
      id: Date.now().toString(),
      createdAt: new Date().toISOString(),
    }
    setNotes((prev) => [...prev, newNote])
    saveNotes([...notes, newNote])
    return newNote
  }

  const updateNote = (id, updates) => {
    setNotes((prev) =>
      prev.map((note) => (note.id === id ? { ...note, ...updates } : note))
    )
    saveNotes(
      notes.map((note) =>
        note.id === id ? { ...note, ...updates } : note
      )
    )
  }

  const deleteNote = (id) => {
    setNotes((prev) => prev.filter((note) => note.id !== id))
    saveNotes(notes.filter((note) => note.id !== id))
  }

  return {
    notes,
    loading,
    addNote,
    updateNote,
    deleteNote,
  }
}
