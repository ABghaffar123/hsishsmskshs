import { useState } from 'react'
import NoteCard from './components/NoteCard'
import { useNotes } from './hooks/useNotes'
import './App.css'

function App() {
  const [showModal, setShowModal] = useState(false)
  const [editingNote, setEditingNote] = useState(null)
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [tags, setTags] = useState('')
  const [selectedColor, setSelectedColor] = useState(0)

  const { notes, addNote, updateNote, deleteNote } = useNotes()

  const colors = ['#fff9c0', '#e3f2fd', '#e8f5e9', '#f3e5f5', '#ffebee', '#fff3e0']
  const colorNames = ['Yellow', 'Blue', 'Green', 'Purple', 'Red', 'Orange']

  const handleSave = () => {
    if (editingNote) {
      updateNote(editingNote.id, { title: title || null, body: body || null, tags: tags.split(',').filter(t => t.trim()) })
    } else {
      addNote({ title: title || null, body: body || null, color: selectedColor, tags: tags.split(',').filter(t => t.trim()) })
    }
    resetModal()
  }

  const handleEdit = (note) => {
    setEditingNote(note)
    setTitle(note.title || '')
    setBody(note.body || '')
    setTags(note.tags ? note.tags.join(', ') : '')
    setSelectedColor(note.color || 0)
    setShowModal(true)
  }

  const handleDelete = (id) => {
    if (window.confirm('Kya aap ye note delete karna chahte hain?')) {
      deleteNote(id)
    }
  }

  const resetModal = () => {
    setShowModal(false)
    setEditingNote(null)
    setTitle('')
    setBody('')
    setTags('')
    setSelectedColor(0)
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>📝 Keep Clone</h1>
        <button onClick={() => setShowModal(true)} className="add-btn">
          + Add Note
        </button>
      </header>

      <main className="notes-grid">
        {notes.map((note) => (
          <NoteCard
            key={note.id}
            note={note}
            onDelete={handleDelete}
            onEdit={handleEdit}
          />
        ))}
      </main>

      {showModal && (
        <div className="modal-overlay" onClick={resetModal}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>{editingNote ? 'Edit Note' : 'New Note'}</h2>

            <input
              type="text"
              placeholder="Title (optional)"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />

            <textarea
              placeholder="Take a note..."
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={4}
            />

            <div className="color-picker">
              <span>Note Color:</span>
              {colors.map((color, index) => (
                <button
                  key={index}
                  className={`color-option ${selectedColor === index ? 'selected' : ''}`}
                  style={{ backgroundColor: color }}
                  onClick={() => setSelectedColor(index)}
                />
              ))}
            </div>

            <input
              type="text"
              placeholder="Tags (comma separated)"
              value={tags}
              onChange={(e) => setTags(e.target.value)}
            />

            <div className="modal-actions">
              <button onClick={handleSave}>Save</button>
              <button onClick={resetModal}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default App
